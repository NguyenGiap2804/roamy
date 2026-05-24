import { Prisma } from '@prisma/client';

import { prisma } from '../../config/db';
import { ScheduleCreateInput, ScheduleUpdateInput } from './schedule.model';

function toDateOnly(date: string) {
  return new Date(`${date}T00:00:00.000Z`);
}

export class ScheduleRepository {
  findAll(userId: string, date?: string) {
    const where: Prisma.ScheduleWhereInput | undefined = date
      ? { userId, date: toDateOnly(date) }
      : { userId };

    return prisma.schedule.findMany({
      where,
      orderBy: [{ date: 'asc' }, { time: 'asc' }],
      include: { place: { include: { category: true } } },
    });
  }

  findById(id: string, userId?: string) {
    return userId ? prisma.schedule.findFirst({
      where: { id, userId },
      include: { place: { include: { category: true } } },
    }) : prisma.schedule.findUnique({
      where: { id },
      include: { place: { include: { category: true } } },
    });
  }

  create(userId: string, data: ScheduleCreateInput) {
    return prisma.schedule.create({
      data: {
        ...data,
        userId,
        date: toDateOnly(data.date),
      },
      include: { place: { include: { category: true } } },
    });
  }

  update(id: string, data: ScheduleUpdateInput) {
    return prisma.schedule.update({
      where: { id },
      data: {
        ...data,
        date: data.date ? toDateOnly(data.date) : undefined,
      },
      include: { place: { include: { category: true } } },
    });
  }

  delete(id: string) {
    return prisma.schedule.delete({ where: { id } });
  }
}

export const scheduleRepository = new ScheduleRepository();
