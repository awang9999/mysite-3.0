// Display date format for ISO YYYY-MM-DD (DESIGN: "the builder chooses the
// display format"). Parsed as a plain string so the date can never shift
// across time zones.
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

export function formatDate(iso: string): string {
  const [year, month, day] = iso.split('-').map(Number);
  return `${MONTHS[month - 1]} ${day}, ${year}`;
}
