export function readStorage<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeStorage<T>(key: string, value: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Ignore storage quota or private browsing errors
  }
}

export function writeStorageBatch(entries: [string, unknown][]): boolean {
  const written: [string, string | null][] = [];
  try {
    for (const [key, value] of entries) {
      const previous = localStorage.getItem(key);
      localStorage.setItem(key, JSON.stringify(value));
      written.push([key, previous]);
    }
    return true;
  } catch {
    for (const [key, previous] of written.reverse()) {
      try {
        if (previous === null) localStorage.removeItem(key);
        else localStorage.setItem(key, previous);
      } catch {
        // Continue restoring keys if storage access changed during the write.
      }
    }
    return false;
  }
}
