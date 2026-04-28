import { z } from 'zod';

export const categoryCreateSchema = z.object({
  body: z.object({
    name: z.string().trim().min(1, 'Category name is required'),
    icon: z.string().trim().min(1, 'Category icon is required'),
  }),
});

export type CategoryCreateInput = z.infer<typeof categoryCreateSchema>['body'];
