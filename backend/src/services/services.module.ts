import { Body, Controller, Get, Module, Post, Patch, Param, ParseUUIDPipe, NotFoundException, BadRequestException } from '@nestjs/common';
import { IsBoolean, IsInt, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service';
import { Public, Roles } from '../common/security';
import { PlainText, SafeText } from '../common/input';

class ServiceDto {
  @PlainText() @SafeText() @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @PlainText(true) @SafeText() @IsString() @MaxLength(300) description!: string;
  @IsInt() @Min(15) @Max(240) durationMin!: number;
  @IsInt() @Min(0) @Max(1000000) priceCents!: number;
  @IsBoolean() rewardEligible!: boolean;
  @IsBoolean() active!: boolean;
}
@Controller('services')
class ServicesController {
  constructor(private readonly db: PrismaService) {}
  @Public() @Get() list() { return this.db.service.findMany({ where: { active: true }, orderBy: { priceCents: 'asc' } }); }
  @Roles('ADMIN') @Get('manage') manage() { return this.db.service.findMany({ orderBy: { name: 'asc' } }); }
  @Roles('ADMIN') @Post() create(@Body() dto: ServiceDto) { if (dto.name.trim().length < 2) throw new BadRequestException('Nombre inválido.'); return this.db.service.create({ data: dto }); }
  @Roles('ADMIN') @Patch(':id') async update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ServiceDto) {
    if (dto.name.trim().length < 2) throw new BadRequestException('Nombre inválido.');
    if (!(await this.db.service.findUnique({ where: { id } }))) throw new NotFoundException('Servicio no encontrado.');
    return this.db.service.update({ where: { id }, data: dto });
  }
}
@Module({ controllers: [ServicesController] })
export class ServicesModule {}
