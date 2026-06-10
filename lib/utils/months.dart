/// Spreadsheet tab month keys, index 0 = January. The income tab for a month is
/// `+key` and the expense tab is `-key` (e.g. "+Jun", "-Jun").
const monthKeys = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String incomeTab(int monthIndex) => '+${monthKeys[monthIndex]}';
String expenseTab(int monthIndex) => '-${monthKeys[monthIndex]}';
