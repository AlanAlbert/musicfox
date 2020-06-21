class MusicInfo {
  int id;
  String title;
  String artist;
  String album;
  String year;
  String comment;
  String genre;
  String track;

  void setId(int id) => this.id = id; 

  void setValue(String title, String artist, String album, String year, String comment, String genre, String track) {
    this.title = title;
    this.artist = artist;
    this.album = album;
    this.year = year;
    this.comment = comment;
    this.genre = genre;
    this.track = track;
  }
}