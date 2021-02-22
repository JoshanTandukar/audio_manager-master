class AudioInfo {
  String url;

  AudioInfo(this.url);

  AudioInfo.fromJson(Map<String, dynamic> json)
      : url = json['url'];

  Map<String, String> toJson() =>
      {
        'url': url,
      };

  @override
  String toString() {
    return 'AudioInfo{url: $url}';
  }
}
