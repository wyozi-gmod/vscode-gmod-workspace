export const pathToGModRelative = (path: string) => {
  const spl = path.split("/garrysmod/");
  if (spl.length > 1) {
    return spl[1];
  } else {
    // oof
    return path;
  }
};
