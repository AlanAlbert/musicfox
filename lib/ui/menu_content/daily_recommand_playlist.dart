import 'package:colorful_cmd/component.dart';
import 'package:musicfox/ui/menu_content/bottom_out_content.dart';
import 'package:musicfox/ui/menu_content/i_menu_content.dart';
import 'package:musicfox/ui/menu_content/playlist_songs.dart';
import 'package:musicfox/utils/function.dart';
import 'package:netease_music_request/request.dart';

class DailyRecommandPlaylist implements IMenuContent {
  List _playlists;

  @override
  bool get isPlayable => false;

  @override
  bool get isResetPlaylist => false;

  @override
  Future<String> getContent(WindowUI ui) => Future.value('');

  @override
  Future<IMenuContent> getMenuContent(WindowUI ui, int index) {
    if (ui.pageData.length - 1 < index || !ui.pageData[index].containsKey('id')) return null;
    return Future.value(PlaylistSongs(ui.pageData[index]['id']));
  }

  @override
  Future<List<String>> getMenus(WindowUI ui) async {
    if (_playlists == null || _playlists.isEmpty) {
      await checkLogin(ui);
      
      var playlist = Playlist();
      Map response = await playlist.getDailyRecommendPlaylists();
      response = validateResponse(response);

      _playlists = response.containsKey('recommend') ? response['recommend'] : [];
    }
    ui.pageData = _playlists;

    var res = <String>[];
    _playlists.forEach((item) {
      var name = '';
      if (item.containsKey('name')) {
        name = item['name'];
      }
      res.add(name);
    });

    return Future.value(res);
  }

  @override
  Future<BottomOutContent> bottomOut(WindowUI ui) => null;
}