import { PrismaClient, ScheduleStatus } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const cafe = await prisma.category.upsert({
    where: { name: 'Cafe' },
    update: { icon: 'local_cafe' },
    create: { name: 'Cafe', icon: 'local_cafe' },
  });

  const food = await prisma.category.upsert({
    where: { name: 'Food' },
    update: { icon: 'restaurant' },
    create: { name: 'Food', icon: 'restaurant' },
  });

  const movie = await prisma.category.upsert({
    where: { name: 'Movie' },
    update: { icon: 'movie' },
    create: { name: 'Movie', icon: 'movie' },
  });

  const themCafe = await prisma.place.upsert({
    where: { id: '11111111-1111-4111-8111-111111111111' },
    update: {},
    create: {
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Thêm Cafe',
      categoryId: cafe.id,
      address: '2HF2+43C, Tân Xã, Hạ Bằng, Hà Nội',
      priceRange: '1-100.000đ/người',
      openingHours: '08:00 - 23:00',
      phone: '+84 984 143 876',
      mapsUrl: 'https://maps.google.com/?q=Them+Cafe+Ha+Noi',
      note: 'Quiet cafe to revisit for planning weekend trips and reading.',
      imageUrl:
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80',
      rating: 4.9,
      hasReminder: true,
    },
  });

  await prisma.place.upsert({
    where: { id: '22222222-2222-4222-8222-222222222222' },
    update: {},
    create: {
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Highland Coffee',
      categoryId: cafe.id,
      address: 'Hà Nội, Việt Nam',
      priceRange: '40.000-80.000đ/người',
      openingHours: '07:00 - 22:00',
      phone: null,
      mapsUrl: 'https://maps.google.com/?q=Highland+Coffee+Ha+Noi',
      note: 'Good backup meeting spot with familiar drinks.',
      imageUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80',
      rating: 4.5,
      hasReminder: false,
    },
  });

  const cgv = await prisma.place.upsert({
    where: { id: '33333333-3333-4333-8333-333333333333' },
    update: {},
    create: {
      id: '33333333-3333-4333-8333-333333333333',
      name: 'CGV Cinema',
      categoryId: movie.id,
      address: 'Vincom Center',
      priceRange: '80.000-150.000đ/người',
      openingHours: '09:00 - 23:30',
      phone: null,
      mapsUrl: 'https://maps.google.com/?q=CGV+Vincom+Center',
      note: 'Save for new movie nights and date plans.',
      imageUrl:
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      hasReminder: true,
    },
  });

  await prisma.schedule.upsert({
    where: { id: '44444444-4444-4444-8444-444444444444' },
    update: {},
    create: {
      id: '44444444-4444-4444-8444-444444444444',
      placeId: themCafe.id,
      date: new Date('2026-04-28T00:00:00.000Z'),
      time: '09:30',
      status: ScheduleStatus.UPCOMING,
      hasReminder: true,
    },
  });

  await prisma.schedule.upsert({
    where: { id: '55555555-5555-4555-8555-555555555555' },
    update: {},
    create: {
      id: '55555555-5555-4555-8555-555555555555',
      placeId: cgv.id,
      date: new Date('2026-04-30T00:00:00.000Z'),
      time: '19:00',
      status: ScheduleStatus.UPCOMING,
      hasReminder: true,
    },
  });

  await prisma.category.update({
    where: { id: food.id },
    data: { icon: 'restaurant' },
  });
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
