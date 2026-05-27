import { ScheduleStatus } from '@prisma/client';
import { z } from 'zod';

const dateSchema = z.iso.date('date must use YYYY-MM-DD format');
const timeSchema = z
  .string()
  .regex(
    /^([01]\d|2[0-3]):[0-5]\d(?:-([01]\d|2[0-3]):[0-5]\d)?$/,
    'time must use HH:mm or HH:mm-HH:mm format',
  );

const scheduleFieldsSchema = z.object({
  placeId: z.uuid('placeId must be a valid UUID').optional().nullable(),
  title: z.string().trim().optional().nullable(),
  note: z.string().trim().optional().nullable(),
  mapsUrl: z.url('mapsUrl must be a valid URL').optional().nullable(),
  date: dateSchema,
  time: timeSchema,
  status: z.enum(ScheduleStatus).default(ScheduleStatus.UPCOMING),
  hasReminder: z.boolean().default(false),
});

const scheduleBaseSchema = scheduleFieldsSchema.superRefine((value, ctx) => {
  if (value.placeId) return;

  if (!value.title?.trim()) {
    ctx.addIssue({
      code: 'custom',
      path: ['title'],
      message: 'title is required when placeId is not provided',
    });
  }

  if (!value.mapsUrl?.trim()) {
    ctx.addIssue({
      code: 'custom',
      path: ['mapsUrl'],
      message: 'mapsUrl is required when placeId is not provided',
    });
  }
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
  body: scheduleFieldsSchema.partial().refine((value) => Object.keys(value).length > 0, {
    message: 'At least one field is required',
  }),
});

export type ScheduleCreateInput = z.infer<typeof scheduleCreateSchema>['body'];
export type ScheduleUpdateInput = z.infer<typeof scheduleUpdateSchema>['body'];
