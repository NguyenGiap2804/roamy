import { z } from 'zod';

const placeBaseSchema = z.object({
  name: z.string().trim().min(1, 'Place name is required'),
  categoryId: z.uuid('categoryId must be a valid UUID'),
  address: z.string().trim().min(1, 'Address is required'),
  priceRange: z.string().trim().optional().nullable(),
  openingHours: z.string().trim().optional().nullable(),
  phone: z.string().trim().optional().nullable(),
  website: z.url('website must be a valid URL').optional().nullable(),
  mapsUrl: z.url('mapsUrl must be a valid URL').optional().nullable(),
  note: z.string().trim().optional().nullable(),
  imageUrl: z.url('imageUrl must be a valid URL').optional().nullable(),
  rating: z.number().min(1).max(5),
  hasReminder: z.boolean().default(false),
  latitude: z.number().optional().nullable(),
  longitude: z.number().optional().nullable(),
});

export const placeIdSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
});

export const placeCreateSchema = z.object({
  body: placeBaseSchema,
});

export const placeUpdateSchema = z.object({
  params: z.object({
    id: z.uuid('id must be a valid UUID'),
  }),
  body: placeBaseSchema.partial().refine((value) => Object.keys(value).length > 0, {
    message: 'At least one field is required',
  }),
});

export type PlaceCreateInput = z.infer<typeof placeCreateSchema>['body'];
export type PlaceUpdateInput = z.infer<typeof placeUpdateSchema>['body'];
