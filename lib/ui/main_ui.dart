import 'dart:async';
import 'dart:io';

import 'package:colorful_cmd/component.dart';
import 'package:colorful_cmd/utils.dart';
import 'package:console/console.dart';
import 'package:mp3_player/audio_player.dart';
import 'package:musicfox/cache/i_cache.dart';
import 'package:musicfox/exception/response_exception.dart';
import 'package:musicfox/lang/chinese.dart';
import 'package:musicfox/ui/menu_content/daily_recommand_playlist.dart';
import 'package:musicfox/ui/menu_content/daily_recommend_songs.dart';
import 'package:musicfox/ui/menu_content/i_menu_content.dart';
import 'package:musicfox/ui/menu_content/user_playlists.dart';
import 'package:musicfox/utils/function.dart';
import 'package:musicfox/utils/music_info.dart';
import 'package:musicfox/utils/music_progress.dart';
import 'package:musicfox/utils/player_status.dart';
import 'package:netease_music_request/request.dart' as request;

final MENU_CONTENTS = <IMenuContent>[
  DailyRecommendSongs(),
  DailyRecommandPlaylist(),
  UserPlaylists()
];

class MainUI {
  WindowUI _window;
  Player _playerContainer;
  String _playingMenu;
  Timer _playerTimer;
  RainbowProgress _playerProgress;
  Stopwatch _watch;
  int _curSongIndex = 0;
  List _playlist = [];
  NotifierProxy _notifier;

  // from player
  MusicInfo _curMusicInfo; 
  MusicProgress _curProgress;
  PlayerStatus _playerStatus;
  

  MainUI() {
    _window = WindowUI(
      name: 'MusicFox', 
      welcomeMsg: 'MUSICFOX', 
      menu: <String>[
        '每日推荐歌曲',
        '每日推荐歌单',
        '我的歌单',
        '私人FM',
        '新歌上架',
        '搜索',
        '排行榜',
        '精选歌单',
        '热门歌手',
        '主播电台',
        '云盘',
      ],
      defaultMenuTitle: '网易云音乐',
      enterMain: enterMain,
      beforeEnterMenu: beforeEnterMenu,
      beforeNextPage: beforeNextPage,
      bottomOut: bottomOut,
      init: init,
      quit: quit,
      lang: Chinese()
    );
    _curMusicInfo = MusicInfo();
    _curProgress = MusicProgress();
    _playerStatus = PlayerStatus();
    _watch = Stopwatch();
    _notifier = NotifierProxy(mac: [TerminalNotifier(), AppleScriptNotifier()], linux: [NotifySendNotifier()]);
    var cache = CacheFactory.produce();
    Map progress = cache.get('progress');
    if (progress == null) return;
    _curSongIndex = progress.containsKey('curSongIndex') ? progress['curSongIndex'] : 0;
    _playlist = progress.containsKey('playlist') ? progress['playlist'] : [];
    _playingMenu = progress.containsKey('playingMenu') ? progress['playingMenu'] : null;
  }

  Future<Player> get _player async {
    if (_playerContainer == null) {
      _playerContainer = await Player.run();
      _playerContainer.listenMusicInfo((musicInfo) {
        _curMusicInfo.setValue(musicInfo['title'], musicInfo['artist'], musicInfo['album'], musicInfo['year'], musicInfo['comment'], musicInfo['genre'], musicInfo['track']);
      });
      _playerContainer.listenProgress((progress) => _curProgress.setValue(progress['cur'], progress['left']));
      _playerContainer.listenStatus((status) async {
        _playerStatus.setStatus(status);
        displayPlayerUI();
        if (!Platform.isWindows && _playerStatus.status == Status.STOPPED) {
          Timer(Duration(milliseconds: 1000), () async {
            if (_playerStatus.status == Status.STOPPED) {
              await nextSong();
            }
          });
        }
      });
    }
    return _playerContainer;
  }

  /// 显示UI
  void display() {
    _window.display();
  }

  /// 清除菜单
  void earseMenu() {
    _window.earseMenu();
  }

  /// 输出错误
  void error(String text) {
    writeLine(ColorText().red(text).normal().toString());
  }

  /// 写信息
  void writeLine(String text) {
    earseMenu();
    Console.moveCursor(row: _window.startRow, column: _window.startColumn);
    Console.write(text);
  }

  /// 初始化
  void init(WindowUI ui) {
    Keys.bindKey(KeyName.SPACE).listen(play);
    Keys.bindKey('[').listen((_) => preSong());
    Keys.bindKey(']').listen((_) => nextSong());
  }

  /// 退出
  void quit(WindowUI ui) async {
    (await _player).quit();
  }

  /// 显示完欢迎界面后
  void enterMain(WindowUI ui) => displayPlayerUI();

  /// 显示播放器UI
  void displayPlayerUI([bool changeSong = false]) {
    if (_playlist == null || _playlist.isEmpty || _curSongIndex == null) return;
    // 歌曲名
    Console.moveCursor(row: Console.rows - 3, column: _window.startColumn);
    var status = _playerStatus.status == Status.PLAYING ? '♫  ♪ ♫  ♪' : '_ _ z Z Z';
    if (changeSong) {
      for (var i = 3; i > 0; i--) {
        Console.eraseLine(2); 
        Console.moveCursorDown();
      }
      Console.moveCursorUp(3);
    } else {
      Console.write('\r');
      for (var i = 1; i < _window.startColumn; i++) {
        Console.write(' ');
      }
    }
    Console.write(ColorText()
      .setColor(_window.primaryColor).text('${status}  ${_playlist[_curSongIndex]['name']} ')
      .gray(getCurSongArtists()).toString());

    // 进度条
    Console.moveCursor(row: Console.rows);
    _playerProgress != null ? _playerProgress.width = Console.columns - 14 : null;
    if (_curMusicInfo.duration != null && _playerProgress != null) {
      _playerProgress.update((_watch.elapsed.inSeconds / _curMusicInfo.duration.inSeconds * 100).round());
    }
    if (Console.columns > 30 && _curMusicInfo.duration != null) {
      var curTime = formatTime(_watch.elapsedMilliseconds);
      var totalTime = formatTime(_curMusicInfo.duration.inMilliseconds);
      Console.moveCursor(row: Console.rows, column: Console.columns - 12);
      Console.write(ColorText().setColor(_window.primaryColor).text('${curTime}/${totalTime}').toString());
    }
  }

  /// 获取当前歌曲的歌手
  String getCurSongArtists() {
    var artistName = '';
    if (_playlist[_curSongIndex].containsKey('artists')) {
        _playlist[_curSongIndex]['artists'].forEach((artist) {
          if (artist.containsKey('name')) {
            artistName = artistName == '' ? artist['name'] : '${artistName},${artist['name']}';
          }
        });
    } else if (_playlist[_curSongIndex].containsKey('ar')) {
        _playlist[_curSongIndex]['ar'].forEach((artist) {
          if (artist.containsKey('name')) {
            artistName = artistName == '' ? artist['name'] : '${artistName},${artist['name']}';
          }
        });
    }
    return '<${artistName}>';
  }

  /// 进入菜单
  Future<dynamic> beforeEnterMenu(WindowUI ui) async {
    try {
      var menu = await getCurMenuContent(ui);
      if (menu == null) return;
      var menus = await menu.getMenus(ui);
      if (menus != null && menus.isNotEmpty) return menus;
      var content = await menu.getContent(ui);
      var row = ui.startRow;
      content.split('\n').forEach((line) {
        Console.moveCursor(row: row, column: ui.startColumn);
        Console.write(line);
        row++;
      });
    } on SocketException {
      error('网络错误~, 请稍后重试');
    } on ResponseException catch (e) {
      error(e.toString());
    }
    return [];
  }

  /// 翻页
  Future<List<String>> beforeNextPage(WindowUI ui) async {
    return Future.value([]);
  }

  /// 获取当前菜单
  Future<IMenuContent> getCurMenuContent(WindowUI ui) async {
    if (ui.menuStack == null || ui.menuStack.isEmpty) return null;
    var lastItem = ui.menuStack.first;
    if (lastItem.index > MENU_CONTENTS.length - 1) return null;
    var menu = MENU_CONTENTS[lastItem.index];

    var stack = ui.menuStack.length > 1 ? ui.menuStack.sublist(1) : [];
    await stack.forEach((menuItem) async {
      menu = await menu.getMenuContent(ui, menuItem.index);
    });

    return menu;
  }

  /// 到底回调
  Future<List<String>> bottomOut(WindowUI ui) async {
    try {
      var menu = await getCurMenuContent(ui);
      if (menu == null) return [];
      var menus = await menu.bottomOut(ui);
      if (menus != null && menus.isNotEmpty) return menus;
    } on SocketException {
      error('网络错误~, 请稍后重试');
    } on ResponseException catch (e) {
      error(e.toString());
    }
    return [];
  }

  /// 空格监听
  void play(_) async {
    var inPlaying = inPlayingMenu();
    var songs = inPlaying ? _playlist : _window.pageData;
    
    var player = (await _player);
    var index = _window.selectIndex;
    var menu = await getCurMenuContent(_window);
    if (menu == null || !menu.isPlayable || songs == null || index > songs.length - 1) {
      if (_playerStatus.status == Status.PAUSED) {
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PLAYING]);
        player.resume();
        if (_watch != null) _watch.start();
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PLAYING]);
      } else if (_playerStatus.status == Status.PLAYING) {
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PAUSED]);
        player.pause();
        if (_watch != null) _watch.stop();
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PAUSED]);
      } else {
        if (_curSongIndex > _playlist.length - 1 || !_playlist[_curSongIndex].containsKey('id')) return;
        await playSong(_playlist[_curSongIndex]['id']);
      }
      return;
    }
    
    _curSongIndex = index;
    Map songInfo = songs[_curSongIndex];
    if (!songInfo.containsKey('id')) return;

    if (inPlaying && _curMusicInfo.id == songInfo['id']) {
      if (_playerStatus.status == Status.PAUSED) {
        player.resume();
        if (_watch != null) _watch.start();
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PLAYING]);
      } else {
        player.pause();
        if (_watch != null) _watch.stop();
        if (Platform.isWindows) _playerStatus.setStatus(STATUS_VALUES[Status.PAUSED]);
      }
    } else {
      _playingMenu = getMenuIndexStack();
      _playlist = songs;
      await playSong(songInfo['id']);
    }

  }

  /// 下一曲
  Future<void> nextSong() async {
    var songs = _playlist;
    if (songs == null || _curSongIndex >= songs.length - 1) return;
    _curSongIndex++;
    Map songInfo = songs[_curSongIndex];
    if (!songInfo.containsKey('id')) return;
    await playSong(songInfo['id']);
  }

  /// 上一曲
  Future<void> preSong() async {
    var songs = _playlist;
    if (songs == null || _curSongIndex <= 0) return;
    _curSongIndex--;
    Map songInfo = songs[_curSongIndex];
    if (!songInfo.containsKey('id')) return;
    await playSong(songInfo['id']);
  }

  /// 定位到相应的播放歌曲
  void locateSong() {
    if (!inPlayingMenu()) return;
    var pageDelta = (_curSongIndex / _window.menuPageSize).floor() - (_window.menuPage - 1);
    if (pageDelta > 0) {
      for (var i = 0; i < pageDelta; i++) {
        _window.nextPage();
      }
    } else if (pageDelta < 0) {
      for (var i = 0; i > pageDelta; i--) {
        _window.prePage ();
      }
    }
    _window.selectIndex = _curSongIndex;
    _window.displayList();
  }

  /// 发送通知
  void notify() {
    if (_curSongIndex > _playlist.length - 1 || !_playlist[_curSongIndex].containsKey('name')) return;
    var songName = _playlist[_curSongIndex]['name'];
    var artist = getCurSongArtists();
    String contentImage;
    if (_playlist[_curSongIndex].containsKey('album')) {
      if (_playlist[_curSongIndex]['album'].containsKey('blurPicUrl') && _playlist[_curSongIndex]['album']['blurPicUrl'] != '') {
        contentImage = _playlist[_curSongIndex]['album']['blurPicUrl'];
      } else if (_playlist[_curSongIndex]['album'].containsKey('picUrl') && _playlist[_curSongIndex]['album']['picUrl'] != '') {
        contentImage = _playlist[_curSongIndex]['album']['picUrl'];
      }
    } else if (_playlist[_curSongIndex].containsKey('al')) {
      if (_playlist[_curSongIndex]['al'].containsKey('blurPicUrl') && _playlist[_curSongIndex]['al']['blurPicUrl'] != '') {
        contentImage = _playlist[_curSongIndex]['al']['blurPicUrl'];
      } else if (_playlist[_curSongIndex]['al'].containsKey('picUrl') && _playlist[_curSongIndex]['al']['picUrl'] != '') {
        contentImage = _playlist[_curSongIndex]['al']['picUrl'];
      }
    }
    var cache = CacheFactory.produce();
    Map user = cache.get('user');
    var avatar = '';
    if (user != null && user.containsKey('avatar')) {
      avatar = user['avatar'];
    }
    _notifier.send(
      '${songName} - ${artist}', 
      title: 'MusicFox', 
      subtitle: '正在播放: ${songName}', 
      groupID: 'musicfox', 
      openURL: 'https://github.com/AlanAlbert/musicfox',
      appIcon: avatar,
      contentImage: contentImage);
  }

  /// 播放指定音乐
  Future<void> playSong(int songId) async {
    _playerStatus.setStatus(STATUS_VALUES[Status.PLAYING]);
    locateSong();
    displayPlayerUI(true);
    notify();
    _watch.stop();
    _watch.reset();
    _watch.start();
    var songRequest = request.Song();
    Map songUrl = await songRequest.getSongUrlByWeb(songId);
    songUrl = songUrl['data'][0];
    if (!songUrl.containsKey('url')) return;
    (await _player).playWithoutList(songUrl['url']);
    _curMusicInfo.setId(songId);
    var duration = 0;
    if (_playlist[_curSongIndex].containsKey('duration')) {
      duration = _playlist[_curSongIndex]['duration'];
    } else if (_playlist[_curSongIndex].containsKey('dt')) {
      duration = _playlist[_curSongIndex]['dt'];
    }
    _curMusicInfo.setDuration(Duration(milliseconds: duration));
    var cache = CacheFactory.produce();
    cache.set('progress', {
      'curSongIndex': _curSongIndex,
      'playlist': _playlist,
      'playingMenu': _playingMenu
    });

    // 播放器进度条
    _playerProgress = RainbowProgress(
      completeChar: '#',
      forwardChar: '#',
      leftDelimiter: '',
      rightDelimiter: '',
      showPercent: false,
      width: Console.columns > 30 ? Console.columns - 14 : Console.columns,
      rainbow: true);
    _playerProgress.update(0);
    if (_playerTimer != null) _playerTimer.cancel();
    _playerTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      displayPlayerUI();
      if (_watch.elapsedMilliseconds >= _curMusicInfo.duration.inMilliseconds) {
        timer.cancel();
        _watch..stop()..reset();
        if (Platform.isWindows) {
          await nextSong();
        }
      }
    });
  }

  /// 是否在播放列表
  bool inPlayingMenu() {
    if (_playingMenu == null) return false;
    return getMenuIndexStack() == _playingMenu;
  }

  /// 获取菜单index栈
  String getMenuIndexStack() {
    var menu = '';
    _window.menuStack.forEach((item) {
      menu = menu == '' ? item.index.toString() : '${menu}>${item.index.toString()}';
    });
    return menu;
  }

}
