import 'package:colorful_cmd/component.dart';
import 'package:colorful_cmd/utils.dart';
import 'package:musicfox/cache/i_cache.dart';
import 'package:musicfox/exception/response_exception.dart';
import 'package:musicfox/ui/login.dart';

/// 检查是否登录，未登录调起登录
Future<void> checkLogin(WindowUI ui) async {
  var cache = CacheFactory.produce();
  var user = cache.get('user');
  if (user == null) await login(ui);
}

/// 验证响应
Map validateResponse(Map response) {
  if (response['code'] == 400) {
    throw ResponseException('输入错误');
  } else {
    if (response['code'] >= 500) {
      throw ResponseException(response['msg'] ?? '');
    }
  }
  return response;
}

/// 格式化秒
String formatTime(int milliseconds) {
  var m = (milliseconds / 60000).floor();
  var s = ((milliseconds / 1000) % 60).floor();
  return '${m >= 10 ? m : '0${m}'}:${s >= 10 ? s : '0${s}'}';
}

/// 获取歌名列表
List<String> getListFromSongs(List songs) {
  var res = <String>[];
  songs.forEach((item) {
    var name = '';
    if (item.containsKey('name')) {
      var artistName = '';
      name = item['name'];
      List artists = item.containsKey('artists') ? item['artists'] : [];
      if (artists.isEmpty) artists = item.containsKey('ar') ? item['ar'] : [];
      artists.forEach((artist) {
        if (artist.containsKey('name')) {
          artistName = artistName == '' ? artist['name'] : '${artistName},${artist['name']}';
        }
      });
      artistName = '<${artistName}>';
      name = '${name} ' + ColorText().gray(artistName).toString();
    }
    res.add(name);
  });
  return res;
}

/// 获取专辑名列表
List<String> getListFromAlbums(List albums) {
  var res = <String>[];
  albums.forEach((album) {
    var name = album.containsKey('name') ? album['name'] : '';
    var artistName = album.containsKey('artist') ? album['artist']['name'] : '';
    artistName = '<${artistName}>';
    name = '${name} ' + ColorText().gray(artistName).toString();

    res.add(name);
  });
  return res;
}

/// 获取歌手列表
List<String> getListFromArtists(List artists) {
  var res = <String>[];
  artists.forEach((artist) {
    var name = artist.containsKey('name') ? artist['name'] : '';
    res.add(name);
  });
  return res;
}

/// 获取歌单列表
List<String> getListFromPlaylists(List playlists) {
  var res = <String>[];
  playlists.forEach((item) {
    var name = item.containsKey('name') ? item['name'] : '';
    res.add(name);
  });
  return res;
}

/// 获取用户列表
List<String> getListFromUsers(List users) {
  var res = <String>[];
  users.forEach((item) {
    var name = item.containsKey('nickname') ? item['nickname'] : '';
    if (item.containsKey('userId')) {
      var userId = ColorText().gray('<${item['userId']}>');
      name = '${name} ${userId}';
    }
    res.add(name);
  });
  return res;
}

/// 获取电台列表
List<String> getListFromDjs(List djs) {
  var res = <String>[];
  djs.forEach((item) {
    var name = item.containsKey('name') ? item['name'] : '';
    res.add(name);
  });
  return res;
}