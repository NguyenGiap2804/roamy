import { ScheduleStatus } from '@prisma/client';
import { z } from 'zod';

const dateSchema = z.iso.date('date must use YYYY-MM-DD format');
const timeSchema = z
  .string()
  .regex(
    /^([01]\d|2[0-3]):[0-5]\d(?:-([01]\d|2[0-3]):[0-5]\d)?$/,
    'time must use HH:mm or HH:mm-HH:mm format',
  );

const scheduleBaseSchema = z.object({
  placeId: z.uuid('placeId must be a valid UUID'),
  date: dateSchema,
  time: timeSchema,
  status: z.enum(ScheduleStatus).default(ScheduleStatus.UPCOMING),
  hasReminder: z.boolean().default(false),
});

export const scheduleListSchema = z.object({
  query: z.object({
    date: dateSchema.optional(),
  }),
});

export const scheduleIdSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
});

export const scheduleCreateSchema = z.object({
  body: scheduleBaseSchema,
});

export const scheduleUpdateSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
  body: scheduleBaseSchema.partial().refine((value) => Object.keys(value).length > 0, {
    message: 'At least one field is required',
  }),
});

export type ScheduleCreateInput = z.infer<typeof scheduleCreateSchema>['body'];
export type ScheduleUpdateInput = z.infer<typeof scheduleUpdateSchema>['body'];
