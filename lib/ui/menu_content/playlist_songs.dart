import 'package:colorful_cmd/component.dart';
import 'package:musicfox/ui/bottom_out_content.dart';
import 'package:musicfox/ui/menu_content/i_menu_content.dart';
import 'package:musicfox/utils/function.dart';
import 'package:netease_music_request/request.dart';

class PlaylistSongs implements IMenuContent {

  int playlistId;
  List _songs;

  @override
  bool get isPlayable => true;

  @override
  bool get isResetPlaylist => false;

  @override
  bool get isDjMenu => false;

  PlaylistSongs(int playlistId) {
    if (this.playlistId != playlistId) _songs = null;
    this.playlistId = playlistId;
  }

  @override
  Future<String> getContent(WindowUI ui) => Future.value('');

  @override
  Future<IMenuContent> getMenuContent(WindowUI ui, int index) => null;

  @override
  Future<List<String>> getMenus(WindowUI ui) async {
    if (playlistId == null) return [];
    if (_songs == null) {
      var playlist = Playlist();
      Map response = await playlist.getPlaylistDetail(playlistId);
      response = validateResponse(ui, response);
      if (response == null) return null;

      List trackIds = response.containsKey('playlist') ? (response['playlist'].containsKey('trackIds') ? response['playlist']['trackIds'] : []) : [];
      var songIds = <int>[];
      if (trackIds.length >= 1000) trackIds = trackIds.getRange(0, 1000).toList();
      trackIds.forEach((item) {
        songIds.add(item['id']);
      });

      var song = Song();
      var songResponse = await song.getSongDetail(songIds);
      songResponse = validateResponse(ui, songResponse);
      _songs = songResponse.containsKey('songs') ? songResponse['songs'] : [];
    }
    ui.pageData = _songs;

    var res = getListFromSongs(_songs);

    return Future.value(res);
  }

  @override
  Future<BottomOutContent> bottomOut(WindowUI ui) => null;
  
  @override
  String getMenuId() => 'PlaylistSongs(${playlistId})';

}
