import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';

import './schema.dart' show VideoSourceFormat;
import './slider.dart' show NewFijkSliderColors, NewFijkSlider;

double speed = 1.0;
bool lockStuff = false;
bool hideLockStuff = false;
bool isFillingNav = false;
final double barHeight = 50.0;
final double barFillingHeight =
    MediaQueryData.fromWindow(window).padding.top + barHeight;
final double barGap = barFillingHeight - barHeight;

String _duration2String(Duration duration) {
  if (duration.inMilliseconds < 0) return "-: negtive";

  String twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  int inHours = duration.inHours;
  return inHours > 0
      ? "$inHours:$twoDigitMinutes:$twoDigitSeconds"
      : "$twoDigitMinutes:$twoDigitSeconds";
}

class CustomFijkPanel extends StatefulWidget {
  final FijkPlayer player;
  final Size viewSize;
  final Rect texturePos;
  final BuildContext? pageContent;
  final String playerTitle;
  final bool showTopCon;
  final Function onChangeVideo;
  final int curTabIdx;
  final int curActiveIdx;
  final bool isFillingNav;
  final Map<String, List<Map<String, dynamic>>> videoList;

  CustomFijkPanel({
    required this.player,
    required this.viewSize,
    required this.texturePos,
    this.pageContent,
    this.playerTitle = "",
    required this.showTopCon,
    required this.onChangeVideo,
    required this.videoList,
    required this.curTabIdx,
    required this.curActiveIdx,
    this.isFillingNav = false,
  });

  @override
  _CustomFijkPanelState createState() => _CustomFijkPanelState();
}

class _CustomFijkPanelState extends State<CustomFijkPanel>
    with TickerProviderStateMixin {
  FijkPlayer get player => widget.player;
  bool get isShowBox => widget.showTopCon;
  Map<String, List<Map<String, dynamic>>> get videoList => widget.videoList;

  VideoSourceFormat? _videoSourceTabs;
  late TabController _tabController;

  bool _lockStuff = lockStuff;
  bool _hideLockStuff = hideLockStuff;
  bool _drawerState = false;
  Timer? _hideLockTimer;

  AnimationController? _animationController;
  Animation<Offset>? _animation;

  void initEvent() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _animation = Tween(
      begin: Offset(1, 0),
      end: Offset.zero,
    ).animate(_animationController!);
    // formant json
    _videoSourceTabs = VideoSourceFormat.fromJson(videoList);
    // is not null
    if (_videoSourceTabs!.video!.length < 1) return null;
    setState(() {
      _tabController = TabController(
        length: _videoSourceTabs!.video!.length,
        vsync: this,
      );
    });
    Wakelock.enable();
  }

  @override
  void initState() {
    super.initState();
    initEvent();
  }

  @override
  void dispose() {
    _hideLockTimer?.cancel();
    _tabController.dispose();
    _animationController!.dispose();
    Wakelock.disable();
    super.dispose();
  }

  // 切换UI 播放列表显示状态
  void changeDrawerState(bool state) {
    if (state) {
      setState(() {
        _drawerState = state;
      });
    }
    Future.delayed(Duration(milliseconds: 10), () {
      _animationController!.forward();
    });
  }

  // 切换UI lock显示状态
  void changeLockState(bool state) {
    setState(() {
      _lockStuff = state;
      if (state == true) {
        _hideLockStuff = true;
        _cancelAndRestartLockTimer();
      }
    });
  }

  // 切换播放源
  void changeCurPlayVideo(int tabIdx, int activeIdx) async {
    await player.stop();
    player.reset().then((_) {
      String curTabActiveUrl =
          _videoSourceTabs!.video![tabIdx]!.list![activeIdx]!.url!;
      player.setDataSource(
        curTabActiveUrl,
        autoPlay: true,
      );
      // 回调
      widget.onChangeVideo(tabIdx, activeIdx);
    });
  }

  void _cancelAndRestartLockTimer() {
    if (_hideLockStuff == true) {
      _startHideLockTimer();
    }
    setState(() {
      _hideLockStuff = !_hideLockStuff;
    });
  }

  void _startHideLockTimer() {
    _hideLockTimer?.cancel();
    _hideLockTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _hideLockStuff = true;
      });
    });
  }

  // 锁 组件
  Widget _buidLockStateDetctor() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cancelAndRestartLockTimer,
      child: Container(
        child: AnimatedOpacity(
          opacity: _hideLockStuff ? 0.0 : 0.7,
          duration: Duration(milliseconds: 400),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                top: widget.isFillingNav && !player.value.fullScreen
                    ? barGap
                    : 0,
              ),
              child: IconButton(
                iconSize: 30,
                onPressed: () {
                  setState(() {
                    _lockStuff = false;
                    _hideLockStuff = true;
                  });
                },
                icon: Icon(Icons.lock_open),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 返回按钮
  Widget _buildTopBackBtn() {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      padding: EdgeInsets.only(
        left: 10.0,
        right: 10.0,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      color: Colors.white,
      onPressed: () {
        // 判断当前是否全屏，如果全屏，退出
        if (widget.player.value.fullScreen) {
          player.exitFullScreen();
        } else {
          if (widget.pageContent == null) return null;
          player.stop();
          Navigator.pop(widget.pageContent!);
        }
      },
    );
  }

  // 播放错误状态
  Widget _buildErrorWidget() {
    return Container(
      color: Colors.transparent,
      height: double.infinity,
      width: double.infinity,
      child: Column(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            child: _buildTopBackBtn(),
          ),
          Expanded(
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 失败图标
                  Icon(
                    Icons.error,
                    size: 50,
                    color: Colors.red,
                  ),
                  // 错误信息
                  Text(
                    "播放失败，您可以点击重试！",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  // 重试
                  ElevatedButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      elevation: MaterialStateProperty.all(0),
                      backgroundColor: MaterialStateProperty.all(Colors.red),
                    ),
                    onPressed: () {
                      // 切换视频
                      changeCurPlayVideo(widget.curTabIdx, widget.curActiveIdx);
                    },
                    child: Text(
                      "点击重试",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 抽屉组件 - 播放列表
  Widget _buildPlayerListDrawer() {
    return Container(
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await _animationController!.reverse();
                setState(() {
                  _drawerState = false;
                });
              },
            ),
          ),
          Container(
            child: SlideTransition(
              position: _animation!,
              child: Container(
                height: window.physicalSize.height,
                width: 320,
                child: buildPlayDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // build 剧集
  Widget buildPlayDrawer() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        automaticallyImplyLeading: false,
        elevation: 0.1,
        title: TabBar(
          tabs:
              _videoSourceTabs!.video!.map((e) => Tab(text: e!.name!)).toList(),
          isScrollable: true,
          controller: _tabController,
        ),
      ),
      body: Container(
        color: Colors.black87,
        child: TabBarView(
          controller: _tabController,
          children: createTabConList(),
        ),
      ),
    );
  }

  // 剧集 tabCon
  List<Widget> createTabConList() {
    List<Widget> list = [];
    _videoSourceTabs!.video!.asMap().keys.forEach((int tabIdx) {
      List<Widget> playListBtns = _videoSourceTabs!.video![tabIdx]!.list!
          .asMap()
          .keys
          .map((int activeIdx) {
        return Padding(
          padding: EdgeInsets.all(5),
          child: ElevatedButton(
            style: ButtonStyle(
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              elevation: MaterialStateProperty.all(0),
              backgroundColor: MaterialStateProperty.all(
                  tabIdx == widget.curTabIdx && activeIdx == widget.curActiveIdx
                      ? Colors.red
                      : Colors.blue),
            ),
            onPressed: () {
              int newTabIdx = tabIdx;
              int newActiveIdx = activeIdx;
              // 切换播放源
              changeCurPlayVideo(newTabIdx, newActiveIdx);
            },
            child: Text(
              _videoSourceTabs!.video![tabIdx]!.list![activeIdx]!.name!,
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        );
      }).toList();
      //
      list.add(
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(left: 5, right: 5),
            child: Wrap(
              direction: Axis.horizontal,
              children: playListBtns,
            ),
          ),
        ),
      );
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    Rect rect = player.value.fullScreen
        ? Rect.fromLTWH(
            0,
            0,
            widget.viewSize.width,
            widget.viewSize.height,
          )
        : Rect.fromLTRB(
            max(0.0, widget.texturePos.left),
            max(0.0, widget.texturePos.top),
            min(widget.viewSize.width, widget.texturePos.right),
            min(widget.viewSize.height, widget.texturePos.bottom),
          );

    List<Widget> ws = [];

    if (player.state == FijkState.error) {
      ws.add(
        _buildErrorWidget(),
      );
    } else {
      if (_lockStuff == true) {
        ws.add(
          _buidLockStateDetctor(),
        );
      } else if (_drawerState == true && widget.player.value.fullScreen) {
        ws.add(
          _buildPlayerListDrawer(),
        );
      } else {
        ws.add(
          _buildGestureDetector(
            curActiveIdx: widget.curActiveIdx,
            curTabIdx: widget.curTabIdx,
            onChangeVideo: widget.onChangeVideo,
            player: widget.player,
            texturePos: widget.texturePos,
            showTopCon: widget.showTopCon,
            pageContent: widget.pageContent,
            playerTitle: widget.playerTitle,
            viewSize: widget.viewSize,
            videoList: widget.videoList,
            changeDrawerState: changeDrawerState,
            changeLockState: changeLockState,
            isFillingNav: widget.isFillingNav,
          ),
        );
      }
    }

    return WillPopScope(
      child: Positioned.fromRect(
        rect: rect,
        child: Stack(
          children: ws,
        ),
      ),
      onWillPop: () async {
        if (!widget.player.value.fullScreen) widget.player.stop();
        return true;
      },
    );
  }
}

// ignore: camel_case_types
class _buildGestureDetector extends StatefulWidget {
  final FijkPlayer player;
  final Size viewSize;
  final Rect texturePos;
  final BuildContext? pageContent;
  final String playerTitle;
  final bool showTopCon;
  final Function onChangeVideo;
  final int curTabIdx;
  final int curActiveIdx;
  final Map<String, List<Map<String, dynamic>>> videoList;
  final Function changeDrawerState;
  final Function changeLockState;
  final bool isFillingNav;
  // 每次重绘的时候，设置显示
  final _hideStuff = false;
  _buildGestureDetector({
    Key? key,
    required this.player,
    required this.viewSize,
    required this.texturePos,
    this.pageContent,
    this.playerTitle = "",
    required this.showTopCon,
    required this.onChangeVideo,
    required this.curTabIdx,
    required this.curActiveIdx,
    required this.videoList,
    required this.changeDrawerState,
    required this.changeLockState,
    required this.isFillingNav,
  }) : super(key: key);

  @override
  _buildGestureDetectorState createState() =>
      _buildGestureDetectorState(this._hideStuff);
}

// ignore: camel_case_types
class _buildGestureDetectorState extends State<_buildGestureDetector> {
  FijkPlayer get player => widget.player;
  bool get isShowBox => widget.showTopCon;
  Map<String, List<Map<String, dynamic>>> get videoList => widget.videoList;

  Duration _duration = Duration();
  Duration _currentPos = Duration();
  Duration _bufferPos = Duration();

  // 滑动后值
  Duration _dargPos = Duration();

  bool _isTouch = false;

  bool _playing = false;
  bool _prepared = false;
  String? _exception;

  double? updatePrevDx;
  double? updatePrevDy;
  int? updatePosX;

  bool? isDargVerLeft;

  double? updateDargVarVal;

  bool varTouchInitSuc = false;

  bool _buffering = false;

  double _seekPos = -1.0;

  StreamSubscription? _currentPosSubs;
  StreamSubscription? _bufferPosSubs;
  StreamSubscription? _bufferingSubs;

  Timer? _hideTimer;
  bool _hideStuff = true;

  bool _hideSpeedStu = true;
  double _speed = speed;

  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.8": 1.8,
    "1.5": 1.5,
    "1.2": 1.2,
    "1.0": 1.0,
  };

  VideoSourceFormat? _videoSourceTabs;

  _buildGestureDetectorState(this._hideStuff);

  void initEvent() {
    // 设置初始化的值，全屏与半屏切换后，重设
    setState(() {
      _speed = speed;
    });
    // formant json
    _videoSourceTabs = VideoSourceFormat.fromJson(videoList);
    // is not null
    if (_videoSourceTabs!.video!.length < 1) return null;
    // url
    String url = _videoSourceTabs!
        .video![widget.curTabIdx]!.list![widget.curActiveIdx]!.url!;
    player.setDataSource(
      url,
      autoPlay: true,
    );
    // 延时隐藏
    _startHideTimer();
  }

  @override
  void dispose() {
    super.dispose();
    _hideTimer?.cancel();

    player.removeListener(_playerValueChanged);
    _currentPosSubs?.cancel();
    _bufferPosSubs?.cancel();
    _bufferingSubs?.cancel();
  }

  @override
  void initState() {
    super.initState();

    initEvent();

    _duration = player.value.duration;
    _currentPos = player.currentPos;
    _bufferPos = player.bufferPos;
    _prepared = player.state.index >= FijkState.prepared.index;
    _playing = player.state == FijkState.started;
    _exception = player.value.exception.message;
    _buffering = player.isBuffering;

    player.addListener(_playerValueChanged);

    _currentPosSubs = player.onCurrentPosUpdate.listen((v) {
      setState(() {
        _currentPos = v;
      });
    });

    _bufferPosSubs = player.onBufferPosUpdate.listen((v) {
      setState(() {
        _bufferPos = v;
      });
    });

    _bufferingSubs = player.onBufferStateUpdate.listen((v) {
      setState(() {
        _buffering = v;
      });
    });
  }

// +++++++++++++++++++++++++++++++++++++++++++

  _onHorizontalDragStart(detills) {
    setState(() {
      updatePrevDx = detills.globalPosition.dx;
      updatePosX = _currentPos.inSeconds;
    });
  }

  _onHorizontalDragUpdate(detills) {
    double curDragDx = detills.globalPosition.dx;
    // 确定当前是前进或者后退
    int cdx = curDragDx.toInt();
    int pdx = updatePrevDx!.toInt();
    bool isBefore = cdx > pdx;
    // + -, 不满足, 左右滑动合法滑动值，> 4
    if (isBefore && cdx - pdx < 3 || !isBefore && pdx - cdx < 3) return null;

    int dragRange = isBefore ? updatePosX! + 1 : updatePosX! - 1;

    // 是否溢出 最大
    int lastSecond = _duration.inSeconds;
    if (dragRange >= _duration.inSeconds) {
      dragRange = lastSecond;
    }
    // 是否溢出 最小
    if (dragRange <= 0) {
      dragRange = 0;
    }
    //
    this.setState(() {
      _hideStuff = false;
      _isTouch = true;
      // 更新下上一次存的滑动位置
      updatePrevDx = curDragDx;
      // 更新时间
      updatePosX = dragRange.toInt();
      _dargPos = Duration(seconds: updatePosX!.toInt());
    });
  }

  _onHorizontalDragEnd(detills) {
    player.seekTo(_dargPos.inMilliseconds);
    this.setState(() {
      _isTouch = false;
      _hideStuff = true;
      _currentPos = _dargPos;
    });
  }

// +++++++++++++++++++++++++++++++++++++++++++

  _onVerticalDragStart(detills) async {
    double clientW = widget.viewSize.width;
    double curTouchPosX = detills.globalPosition.dx;

    setState(() {
      // 更新位置
      updatePrevDy = detills.globalPosition.dy;
      // 是否左边
      isDargVerLeft = (curTouchPosX > (clientW / 2)) ? false : true;
    });
    // 大于 右边 音量 ， 小于 左边 亮度
    if (!isDargVerLeft!) {
      // 音量
      await FijkVolume.getVol().then((double v) {
        varTouchInitSuc = true;
        setState(() {
          updateDargVarVal = v;
        });
      });
    } else {
      // 亮度
      await FijkPlugin.screenBrightness().then((double v) {
        varTouchInitSuc = true;
        setState(() {
          updateDargVarVal = v;
        });
      });
    }
  }

  _onVerticalDragUpdate(detills) {
    if (!varTouchInitSuc) return null;
    double curDragDy = detills.globalPosition.dy;
    // 确定当前是前进或者后退
    int cdy = curDragDy.toInt();
    int pdy = updatePrevDy!.toInt();
    bool isBefore = cdy < pdy;
    // + -, 不满足, 上下滑动合法滑动值，> 3
    if (isBefore && pdy - cdy < 3 || !isBefore && cdy - pdy < 3) return null;
    // 区间
    double dragRange =
        isBefore ? updateDargVarVal! + 0.03 : updateDargVarVal! - 0.03;
    // 是否溢出
    if (dragRange > 1) {
      dragRange = 1.0;
    }
    if (dragRange < 0) {
      dragRange = 0.0;
    }
    setState(() {
      updatePrevDy = curDragDy;
      varTouchInitSuc = true;
      updateDargVarVal = dragRange;
      // 音量
      if (!isDargVerLeft!) {
        FijkVolume.setVol(dragRange);
      } else {
        FijkPlugin.setScreenBrightness(dragRange);
      }
    });
  }

  _onVerticalDragEnd(detills) {
    setState(() {
      varTouchInitSuc = false;
    });
  }

// +++++++++++++++++++++++++++++++++++++++++++

  void _playerValueChanged() async {
    // await player.stop();
    FijkValue value = player.value;
    if (value.duration != _duration) {
      setState(() {
        _duration = value.duration;
      });
    }
    print(
        '+++++++++ $value.state  播放器状态  ${value.state == FijkState.started} ++++++++++');
    bool playing = (value.state == FijkState.started);
    bool prepared = value.prepared;
    String? exception = value.exception.message;
    // 状态不一致，修改
    if (playing != _playing ||
        prepared != _prepared ||
        exception != _exception) {
      setState(() {
        _playing = playing;
        _prepared = prepared;
        _exception = exception;
      });
    }
    // 播放完成
    bool playend = (value.state == FijkState.completed);
    String nextVideoUrl = _videoSourceTabs!
        .video![widget.curTabIdx]!.list![widget.curActiveIdx + 1]!.url!;
    // bool isOverFlowTabLen =
    //     widget.curTabIdx + 1 >= _videoSourceTabs!.video!.length;
    // bool isOverFlowActiveLen = isOverFlowTabLen &&
    //     widget.curActiveIdx + 1 >=
    //         _videoSourceTabs!.video![widget.curTabIdx]!.list!.length;
    // 播放完成 && tablen没有溢出 && curActive没有溢出
    // ignore: unnecessary_null_comparison
    if (playend && nextVideoUrl != null) {
      int newTabIdx = widget.curTabIdx;
      int newActiveIdx = widget.curActiveIdx + 1;
      widget.onChangeVideo(newTabIdx, newActiveIdx);
      // 切换播放源
      changeCurPlayVideo(newTabIdx, newActiveIdx);
    }
  }

  // 切换播放源
  void changeCurPlayVideo(int tabIdx, int activeIdx) async {
    await player.stop();
    setState(() {
      _buffering = false;
    });
    player.reset().then((_) {
      _speed = speed = 1.0;
      String curTabActiveUrl =
          _videoSourceTabs!.video![tabIdx]!.list![activeIdx]!.url!;
      player.setDataSource(
        curTabActiveUrl,
        autoPlay: true,
      );
      // 回调
      widget.onChangeVideo(tabIdx, activeIdx);
    });
  }

  void _playOrPause() {
    if (_playing == true) {
      player.pause();
    } else {
      player.start();
    }
  }

  void _cancelAndRestartTimer() {
    if (_hideStuff == true) {
      _startHideTimer();
    }

    setState(() {
      _hideStuff = !_hideStuff;
      if (_hideStuff == true) {
        _hideSpeedStu = true;
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _hideStuff = true;
        _hideSpeedStu = true;
      });
    });
  }

  // 底部控制栏 - 播放按钮
  Widget _buildPlayStateBtn() {
    IconData iconData = _playing ? Icons.pause : Icons.play_arrow;

    return IconButton(
      icon: Icon(iconData),
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 10.0,
        right: 10.0,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onPressed: _playOrPause,
    );
  }

  // 控制器ui 底部
  AnimatedOpacity _buildBottomBar(BuildContext context) {
    double duration = _duration.inMilliseconds.toDouble();
    double currentValue =
        _seekPos > 0 ? _seekPos : _currentPos.inMilliseconds.toDouble();
    currentValue = min(currentValue, duration);
    currentValue = max(currentValue, 0);

    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 0.8,
      duration: Duration(milliseconds: 400),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [
              Color.fromRGBO(0, 0, 0, 0),
              Color.fromRGBO(0, 0, 0, 1),
            ],
          ),
        ),
        child: Row(
          children: <Widget>[
            // 按钮 - 播放/暂停
            _buildPlayStateBtn(),
            // 下一集
            IconButton(
              icon: Icon(Icons.skip_next),
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 10.0,
                right: 10.0,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () {
                bool isOverFlowActiveLen = widget.curActiveIdx + 1 >
                    _videoSourceTabs!.video![widget.curTabIdx]!.list!.length;
                // 播放完成
                if (!isOverFlowActiveLen) {
                  int newTabIdx = widget.curTabIdx;
                  int newActiveIdx = widget.curActiveIdx + 1;
                  // 切换播放源
                  changeCurPlayVideo(newTabIdx, newActiveIdx);
                }
              },
            ),
            // 已播放时间
            Padding(
              padding: EdgeInsets.only(right: 5.0, left: 5),
              child: Text(
                '${_duration2String(_currentPos)}',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.white,
                ),
              ),
            ),
            // 播放进度 if 没有开始播放 占满，空ui， else fijkSlider widget
            _duration.inMilliseconds == 0
                ? Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 5, left: 5),
                      child: NewFijkSlider(
                        colors: NewFijkSliderColors(
                          cursorColor: Colors.blue,
                          playedColor: Colors.blue,
                        ),
                        onChangeEnd: (double value) {},
                        value: 0,
                        onChanged: (double value) {},
                      ),
                    ),
                  )
                : Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 5, left: 5),
                      child: NewFijkSlider(
                        colors: NewFijkSliderColors(
                          cursorColor: Colors.blue,
                          playedColor: Colors.blue,
                        ),
                        value: currentValue,
                        cacheValue: _bufferPos.inMilliseconds.toDouble(),
                        min: 0.0,
                        max: duration,
                        onChanged: (v) {
                          _startHideTimer();
                          setState(() {
                            _seekPos = v;
                          });
                        },
                        onChangeEnd: (v) {
                          setState(() {
                            player.seekTo(v.toInt());
                            print("seek to $v");
                            _currentPos =
                                Duration(milliseconds: _seekPos.toInt());
                            _seekPos = -1;
                          });
                        },
                      ),
                    ),
                  ),

            // 总播放时间
            _duration.inMilliseconds == 0
                ? Container(
                    child: const Text(
                      "00:00",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(right: 5.0, left: 5),
                    child: Text(
                      '${_duration2String(_duration)}',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
            // 倍数按钮
            widget.player.value.fullScreen
                ? Ink(
                    padding: EdgeInsets.all(5),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _hideSpeedStu = !_hideSpeedStu;
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 40,
                        height: 30,
                        child: Text(
                          _speed.toString() + " X",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  )
                : Container(),
            // 剧集按钮
            widget.player.value.fullScreen
                ? Ink(
                    padding: EdgeInsets.all(5),
                    child: InkWell(
                      onTap: () {
                        // 调用父组件的回调
                        widget.changeDrawerState(true);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 40,
                        height: 30,
                        child: Text(
                          "剧集",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  )
                : Container(),
            // 按钮 - 全屏/退出全屏
            IconButton(
              icon: Icon(widget.player.value.fullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen),
              padding: EdgeInsets.only(left: 10.0, right: 10.0),
              color: Colors.white,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () {
                if (widget.player.value.fullScreen) {
                  player.exitFullScreen();
                } else {
                  player.enterFullScreen();
                  // 掉父组件回调
                  widget.changeDrawerState(false);
                }
              },
            )
            //
          ],
        ),
      ),
    );
  }

  // 返回按钮
  Widget _buildTopBackBtn() {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      padding: EdgeInsets.only(
        left: 10.0,
        right: 10.0,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      color: Colors.white,
      onPressed: () {
        // 判断当前是否全屏，如果全屏，退出
        if (widget.player.value.fullScreen) {
          player.exitFullScreen();
        } else {
          if (widget.pageContent == null) return null;
          player.stop();
          Navigator.pop(widget.pageContent!);
        }
      },
    );
  }

  // 播放器顶部 返回 + 标题
  Widget _buildTopBar() {
    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 0.8,
      duration: Duration(milliseconds: 400),
      child: Container(
        height: widget.isFillingNav && !widget.player.value.fullScreen
            ? barFillingHeight
            : barHeight,
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [
              Color.fromRGBO(0, 0, 0, 1),
              Color.fromRGBO(0, 0, 0, 0),
            ],
          ),
        ),
        child: Container(
          height: barHeight,
          child: Row(
            children: <Widget>[
              _buildTopBackBtn(),
              Expanded(
                child: Container(
                  child: Text(
                    widget.playerTitle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 居中播放按钮
  Widget _buildCenterPlayBtn() {
    return Container(
      color: Colors.transparent,
      height: double.infinity,
      width: double.infinity,
      child: Center(
        child: (_prepared && !_buffering)
            ? AnimatedOpacity(
                opacity: _hideStuff ? 0.0 : 0.7,
                duration: Duration(milliseconds: 400),
                child: IconButton(
                  iconSize: barHeight * 1.2,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white),
                  padding: EdgeInsets.only(left: 10.0, right: 10.0),
                  onPressed: _playOrPause,
                ),
              )
            : SizedBox(
                width: barHeight,
                height: barHeight,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
      ),
    );
  }

  // build 滑动进度时间显示
  Widget buildDargProgressTime() {
    return _isTouch
        ? Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(5),
              ),
              color: Color.fromRGBO(0, 0, 0, 0.8),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: Text(
                '${_duration2String(_dargPos)} / ${_duration2String(_duration)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          )
        : Container();
  }

  // build 显示垂直亮度，音量
  Widget buildDargVolumeAndBrightness() {
    // 不显示
    if (!varTouchInitSuc) return Container();

    IconData iconData;
    // 判断当前值范围，显示的图标
    if (updateDargVarVal! <= 0) {
      iconData = !isDargVerLeft! ? Icons.volume_mute : Icons.brightness_low;
    } else if (updateDargVarVal! < 0.5) {
      iconData = !isDargVerLeft! ? Icons.volume_down : Icons.brightness_medium;
    } else {
      iconData = !isDargVerLeft! ? Icons.volume_up : Icons.brightness_high;
    }
    // 显示，亮度 || 音量
    return Card(
      color: Color.fromRGBO(0, 0, 0, 0.8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              iconData,
              color: Colors.white,
            ),
            Container(
              width: 100,
              height: 3,
              margin: EdgeInsets.only(left: 8),
              child: LinearProgressIndicator(
                value: updateDargVarVal,
                backgroundColor: Colors.white54,
                valueColor: AlwaysStoppedAnimation(Colors.lightBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // build 倍数列表
  List<Widget> buildSpeedListWidget() {
    List<Widget> columnChild = [];
    speedList.forEach((String mapKey, double speedVals) {
      columnChild.add(
        Ink(
          child: InkWell(
            onTap: () {
              if (_speed == speedVals) return null;
              setState(() {
                _speed = speed = speedVals;
                _hideSpeedStu = true;
                player.setSpeed(speedVals);
              });
            },
            child: Container(
              alignment: Alignment.center,
              width: 50,
              height: 24,
              child: Text(
                mapKey + " X",
                style: TextStyle(
                  color: _speed == speedVals ? Colors.blue : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
      columnChild.add(
        Padding(
          padding: EdgeInsets.only(top: 5, bottom: 5),
          child: Container(
            width: 50,
            height: 1,
            color: Colors.white54,
          ),
        ),
      );
    });
    columnChild.removeAt(columnChild.length - 1);
    return columnChild;
  }

  // 播放器控制器 ui
  Widget _buildGestureDetector() {
    return GestureDetector(
      onTap: _cancelAndRestartTimer,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AbsorbPointer(
        absorbing: _hideStuff,
        child: Column(
          children: <Widget>[
            // 播放器顶部控制器
            isShowBox ? _buildTopBar() : Container(),
            // 中间按钮
            Expanded(
              child: Container(
                child: Stack(
                  children: <Widget>[
                    // 顶部显示
                    Positioned(
                      top: widget.player.value.fullScreen ? 20 : 0,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 显示左右滑动快进时间的块
                          buildDargProgressTime(),
                          // 显示上下滑动音量亮度
                          buildDargVolumeAndBrightness()
                        ],
                      ),
                    ),
                    // 中间按钮
                    Align(
                      alignment: Alignment.center,
                      child: _buildCenterPlayBtn(),
                    ),
                    // 倍数选择
                    Positioned(
                      right: 88,
                      bottom: 0,
                      child: !_hideSpeedStu
                          ? Container(
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  children: buildSpeedListWidget(),
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            )
                          : Container(),
                    ),
                    // 锁按钮
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedOpacity(
                        opacity: _hideStuff ? 0.0 : 0.7,
                        duration: Duration(milliseconds: 400),
                        child: Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: IconButton(
                            iconSize: 30,
                            onPressed: () {
                              // 更改 ui显示状态
                              widget.changeLockState(true);
                            },
                            icon: Icon(Icons.lock_outline),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 播放器底部控制器
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildGestureDetector();
  }
}
