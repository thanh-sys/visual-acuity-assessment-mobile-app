

/// Calculates the required font size in logical pixels to match the standard Snellen chart.
///
/// [snellenLine] is the denominator of the vision line, e.g., 40 for "20/40".
/// [screenPpi] is the calibrated Pixels Per Inch of the device.
/// [devicePixelRatio] is the number of physical pixels for each logical pixel.
double getCalibratedFontSize({
  required double snellenLine,
  required double screenPpi,
  required double devicePixelRatio,
}) {
  const double fontCorrectionFactor = 1.4285714;
  // --- INFOR MATION ĐẦU VÀO ---
  print('--- Debug Tính Font Size Snellen ---');
  print('1. Snellen Line (X trong 20/X): $snellenLine');
  print('2. Screen PPI (Đã hiệu chỉnh): $screenPpi');
  print('3. Device Pixel Ratio (DPR): $devicePixelRatio');
  print('-------------------------------------');

  // Chiều cao tiêu chuẩn của chữ cái ở dòng 20/20 là 4.375mm (khi đo ở 3m).
  const double baseLetterHeightMm = 4.375;
  print('Hằng số: Chiều cao 20/20 (3m): $baseLetterHeightMm mm');
  
  // 1 inch = 25.4 mm.
  const double mmPerInch = 25.4;
  
  // 1. Tính chiều cao vật lý (mm) của chữ cái cho dòng Snellen tương ứng.
  double targetLetterHeightMm = baseLetterHeightMm * (snellenLine / 20.0);
  
  print('1. Chiều cao mục tiêu: $targetLetterHeightMm mm'); // Ví dụ 20/70 = 15.3125 mm

  // 2. Chuyển đổi chiều cao từ mm sang inch.
  final double targetLetterHeightInches = targetLetterHeightMm / mmPerInch;
  print('2. Chiều cao mục tiêu: $targetLetterHeightInches inch');

  // 3. Tính chiều cao cần thiết bằng pixel vật lý, dựa trên PPI của màn hình.
  final double targetHeightPhysicalPixels = targetLetterHeightInches * screenPpi;
  print('3. Chiều cao mục tiêu: $targetHeightPhysicalPixels physical pixels'); // Số pixel cần thiết

  // 4. Chuyển đổi từ pixel vật lý sang pixel logic (đơn vị Flutter/iOS)
  final double fontSizeLogicalPixels = targetHeightPhysicalPixels / devicePixelRatio;
  print('4. Font Size cần dùng: $fontSizeLogicalPixels logical pixels (dp/pt)');
  print('-------------------------------------');

  // final double calibratedFontSize = fontSizeLogicalPixels * fontCorrectionFactor;

  // Debug (Tùy chọn)
  print('Font Size gốc (chưa hiệu chỉnh): $fontSizeLogicalPixels dp');
  // print('Font Size cuối cùng (đã hiệu chỉnh): $calibratedFontSize dp');

  return fontSizeLogicalPixels;
}