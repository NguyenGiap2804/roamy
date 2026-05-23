import { z } from 'zod';

export const categoryCreateSchema = z.object({
  body: z.object({
    name: z.string().trim().min(1, 'Category name is required'),
    icon: z.string().trim().min(1, 'Category icon is required'),
  }),
});

export const categoryIdSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
});

export const categoryUpdateSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
  body: z
    .object({
      name: z.string().trim().min(1, 'Category name is required').optional(),
      icon: z.string().trim().min(1, 'Category icon is required').optional(),
    })
    .refine((value) => Object.keys(value).length > 0, {
      message: 'At least one field is required',
    }),
});

export type CategoryCreateInput = z.infer<typeof categoryCreateSchema>['body'];
export type CategoryUpdateInput = z.infer<typeof categoryUpdateSchema>['body'];
