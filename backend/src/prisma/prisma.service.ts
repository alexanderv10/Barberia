import { Injectable, OnModuleInit, OnModuleDestroy, Global, Module, ConflictException } from '@nestjs/common';
import { PrismaClient, Prisma } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() { await this.$connect(); }
  async onModuleDestroy() { await this.$disconnect(); }

  async atomic<T>(action: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        return await this.$transaction(action, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          maxWait: 10000,
          timeout: 15000,
        });
      } catch (error) {
        const e = error as { code?: string; meta?: unknown; message?: string };
        // The PostgreSQL connector can surface SQLSTATE 40P01 as an unknown Prisma error
        // when concurrent inserts contend on GiST exclusion constraints.
        const retryable = ['P2034', 'P2028', 'P2024'].includes(e.code ?? '') ||
          /40P01|40001|deadlock detected|could not serialize access/.test(e.message ?? '');
        if (retryable && attempt < 2) continue;
        if (e.code === 'P2002' || retryable ||
            /23P01|no_overlap|one_pending_reward/.test(JSON.stringify(e.meta) + e.message)) {
          throw new ConflictException('El horario o beneficio ya fue utilizado. Actualiza e inténtalo de nuevo.');
        }
        throw error;
      }
    }
    throw new ConflictException('Inténtalo de nuevo.');
  }
}

@Global()
@Module({ providers: [PrismaService], exports: [PrismaService] })
export class PrismaModule {}
