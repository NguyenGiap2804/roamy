import assert from "node:assert/strict";
import test from "node:test";

import { placeCreateSchema } from "../src/modules/place/place.model";

test("place create schema keeps website details", () => {
  const parsed = placeCreateSchema.parse({
    body: {
      name: "The Cofftea",
      categoryId: "11111111-1111-4111-8111-111111111111",
      address: "123 Pho Hue, Ha Noi",
      priceRange: "",
      openingHours: "",
      phone: "+84 123 456 789",
      website: "https://thecofftea.example",
      mapsUrl: "https://www.google.com/maps/place/The+Cofftea",
      note: null,
      imageUrl: "https://example.com/photo.jpg",
      rating: 4.6,
      hasReminder: false,
      latitude: 21.0123,
      longitude: 105.85,
    },
  });

  assert.equal(parsed.body.website, "https://thecofftea.example");
});
