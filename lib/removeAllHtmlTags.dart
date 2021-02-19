//Removes Html tags and fixes broken characters in parsed data

String removeAllHtmlTags(String htmlText) {
  RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  return htmlText
      .replaceAll(exp, '')
      .replaceAll('Ý', 'İ')
      .replaceAll('ý', 'ı')
      .replaceAll('Þ', 'Ş');
}
