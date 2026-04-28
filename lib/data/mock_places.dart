import '../models/place.dart';

const mockPlaces = <Place>[
  Place(
    id: 'them-cafe',
    name: 'Them Cafe',
    categoryId: 'cafe',
    categoryName: 'Cafe',
    address: '2HF2+43C, Tan Xa, Ha Noi',
    priceRange: '1-100.000d/nguoi',
    openingHours: '08:00 - 23:00',
    phone: '+84 984 143 876',
    mapsUrl: 'https://maps.google.com/?q=Them+Cafe+Ha+Noi',
    note: 'Quiet cafe to revisit for planning weekend trips and reading.',
    imageUrl:
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80',
    rating: 4.9,
    hasReminder: true,
  ),
  Place(
    id: 'highland-coffee',
    name: 'Highland Coffee',
    categoryId: 'cafe',
    categoryName: 'Cafe',
    address: 'Ha Noi, Viet Nam',
    priceRange: '40.000-80.000d/nguoi',
    openingHours: '07:00 - 22:00',
    phone: 'Not added yet',
    mapsUrl: 'https://maps.google.com/?q=Highland+Coffee+Ha+Noi',
    note: 'Good backup meeting spot with familiar drinks.',
    imageUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80',
    rating: 4.5,
    hasReminder: false,
  ),
  Place(
    id: 'cgv-cinema',
    name: 'CGV Cinema',
    categoryId: 'movie',
    categoryName: 'Movie',
    address: 'Vincom Center',
    priceRange: '80.000-150.000d/nguoi',
    openingHours: '09:00 - 23:30',
    phone: 'Not added yet',
    mapsUrl: 'https://maps.google.com/?q=CGV+Vincom+Center',
    note: 'Save for new movie nights and date plans.',
    imageUrl:
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=80',
    rating: 4.6,
    hasReminder: true,
  ),
];
