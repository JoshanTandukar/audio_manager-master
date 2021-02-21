class AudioInfo {
  String url;
  String desc;
  String coverUrl;

  AudioInfo(this.url, {this.desc, this.coverUrl});

  AudioInfo.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        desc = json['desc'],
        coverUrl = json['coverUrl'];

  Map<String, String> toJson() => {
        'url': url,
        'desc': desc,
        'coverUrl': coverUrl,
      };

  @override
  String toString() {
    return 'AudioInfo{url: $url, desc: $desc, coverUrl: $coverUrl}';
  }
}
