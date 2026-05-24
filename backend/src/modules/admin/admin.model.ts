import { z } from "zod";

const userIdSchema = z.string().trim().min(1);
const adminUserEmailSchema = z.string().trim().toLowerCase().email();

export const adminCreateUserSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(80),
    email: adminUserEmailSchema,
  }),
});

export const adminUserIdSchema = z.object({
  params: z.object({
    id: userIdSchema,
  }),
});

export const adminDeleteUserSchema = z.object({
  params: z.object({
    id: userIdSchema,
  }),
  body: z.object({
    confirmEmail: adminUserEmailSchema,
  }),
});

export type AdminCreateUserInput = z.infer<
  typeof adminCreateUserSchema
>["body"];
