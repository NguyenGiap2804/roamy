bool hasUsableCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return false;
  }

  if (!latitude.isFinite || !longitude.isFinite) {
    return false;
  }

  if (latitude < -90 || latitude > 90) {
    return false;
  }

  if (longitude < -180 || longitude > 180) {
    return false;
  }

  // The backend may persist 0,0 as a placeholder for "missing coordinates".
  if (latitude == 0 && longitude == 0) {
    return false;
  }

  return true;
}
