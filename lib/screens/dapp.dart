import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptowallet/screens/custom_image.dart';
import 'package:cryptowallet/screens/main_screen.dart';
import 'package:cryptowallet/screens/saved_urls.dart';
import 'package:cryptowallet/screens/security.dart';
import 'package:cryptowallet/screens/settings.dart';
import 'package:cryptowallet/screens/wallet_main_body.dart';
import 'package:cryptowallet/screens/webview_tab.dart';
import 'package:cryptowallet/utils/app_config.dart';
import 'package:cryptowallet/utils/slide_up_panel.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:page_transition/page_transition.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/web3dart.dart' as web3;
import '../utils/rpc_urls.dart';
import 'package:flutter_gen/gen_l10n/app_localization.dart';

class Dapp extends StatefulWidget {
  final String provider;
  final String init;
  final String data;
  const Dapp({
    Key key,
    this.data,
    this.provider,
    this.init,
  }) : super(key: key);
  @override
  State<Dapp> createState() => _DappState();
}

class _DappState extends State<Dapp> {
  final browserController = TextEditingController();

  ValueNotifier loadingPercent = ValueNotifier<double>(0);
  String urlLoaded = '';
  InAppWebViewController _controller;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool showWebViewTabsViewer = false;
  String initJs = '';
  List<WebViewTab> webViewTabs = [];
  int currentTabIndex = 0;
  final kHomeUrl = 'https://google.com';
  @override
  initState() {
    super.initState();

    initJs = widget.init;
    webViewTabs.add(createWebViewTab());
  }

  @override
  void dispose() {
    browserController.dispose();
    super.dispose();
  }

  WebViewTab createWebViewTab({String url, int windowId}) {
    WebViewTab webViewTab;

    if (url == null && windowId == null) {
      url = kHomeUrl;
    }

    webViewTab = WebViewTab(
      key: GlobalKey(),
      url: url,
      provider: widget.provider,
      init: widget.init,
      data: widget.data,
      windowId: windowId,
      onStateUpdated: () {
        setState(() {});
      },
      onCloseTabRequested: () {
        if (webViewTab != null) {
          _closeWebViewTab(webViewTab);
        }
      },
      onCreateTabRequested: (createWindowAction) {
        _addWebViewTab(windowId: createWindowAction.windowId);
      },
    );
    return webViewTab;
  }

  AppBar _buildWebViewTabAppBar() {
    return AppBar(
      leading: IconButton(
          onPressed: () {
            _addWebViewTab();
          },
          icon: const Icon(Icons.add)),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            webViewTabs[currentTabIndex].title ?? '',
            overflow: TextOverflow.fade,
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              webViewTabs[currentTabIndex].isSecure != null
                  ? Icon(
                      webViewTabs[currentTabIndex].isSecure == true
                          ? Icons.lock
                          : Icons.lock_open,
                      color: webViewTabs[currentTabIndex].isSecure == true
                          ? Colors.green
                          : Colors.red,
                      size: 12)
                  : Container(),
              const SizedBox(
                width: 5,
              ),
              Flexible(
                  child: Text(
                webViewTabs[currentTabIndex].currentUrl ??
                    webViewTabs[currentTabIndex].url ??
                    '',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.fade,
              )),
            ],
          )
        ],
      ),
      actions: _buildWebViewTabActions(),
    );
  }

  Widget _buildWebViewTabs() {
    return IndexedStack(index: currentTabIndex, children: webViewTabs);
  }

  List<Widget> _buildWebViewTabActions() {
    return [
      IconButton(
        onPressed: () async {
          await webViewTabs[currentTabIndex].updateScreenshot();
          setState(() {
            showWebViewTabsViewer = true;
          });
        },
        icon: Container(
          margin: const EdgeInsets.only(top: 5, bottom: 5),
          decoration: BoxDecoration(
              border: Border.all(width: 2.0, color: Colors.white),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(5.0)),
          constraints: const BoxConstraints(minWidth: 25.0),
          child: Center(
              child: Text(
            webViewTabs.length.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.0),
          )),
        ),
      ),
    ];
  }

  AppBar _buildWebViewTabViewerAppBar() {
    return AppBar(
      leading: IconButton(
          onPressed: () {
            setState(() {
              showWebViewTabsViewer = false;
            });
          },
          icon: const Icon(Icons.arrow_back)),
      title: const Text('WebView Tab Viewer'),
      actions: _buildWebViewTabsViewerActions(),
    );
  }

  Widget _buildWebViewTabsViewer() {
    return GridView.count(
      crossAxisCount: 2,
      children: webViewTabs.map((webViewTab) {
        return _buildWebViewTabGrid(webViewTab);
      }).toList(),
    );
  }

  Widget _buildWebViewTabGrid(WebViewTab webViewTab) {
    final webViewIndex = webViewTabs.indexOf(webViewTab);
    final screenshotData = webViewTab.screenshot;
    final favicon = webViewTab.favicon;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
          side: currentTabIndex == webViewIndex
              ? const BorderSide(
                  // border color
                  color: Colors.black,
                  // border thickness
                  width: 2)
              : BorderSide.none,
          borderRadius: const BorderRadius.all(
            Radius.circular(5),
          )),
      child: InkWell(
        onTap: () {
          _selectWebViewTab(webViewTab);
        },
        child: Column(
          children: [
            ListTile(
              tileColor: Colors.black12,
              selected: currentTabIndex == webViewIndex,
              selectedColor: Colors.white,
              selectedTileColor: Colors.black,
              contentPadding: const EdgeInsets.only(left: 10),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              title: Row(mainAxisSize: MainAxisSize.max, children: [
                Container(
                  padding: const EdgeInsets.only(right: 10),
                  child: favicon != null
                      ? CustomImage(
                          url: favicon.url, maxWidth: 20.0, height: 20.0)
                      : null,
                ),
                Expanded(
                    child: Text(
                  webViewTab.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ))
              ]),
              trailing: IconButton(
                  onPressed: () {
                    _closeWebViewTab(webViewTab);
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                  )),
            ),
            Expanded(
                child: Ink(
              decoration: screenshotData != null
                  ? BoxDecoration(
                      image: DecorationImage(
                      image: MemoryImage(screenshotData),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                    ))
                  : null,
            ))
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWebViewTabsViewerActions() {
    return [
      IconButton(
          onPressed: () {
            _closeAllWebViewTabs();
          },
          icon: const Icon(Icons.clear_all))
    ];
  }

  void _addWebViewTab({String url, int windowId}) {
    webViewTabs.add(createWebViewTab(url: url, windowId: windowId));
    setState(() {
      currentTabIndex = webViewTabs.length - 1;
    });
  }

  void _selectWebViewTab(WebViewTab webViewTab) {
    final webViewIndex = webViewTabs.indexOf(webViewTab);
    webViewTabs[currentTabIndex].pause();
    webViewTab.resume();
    setState(() {
      currentTabIndex = webViewIndex;
      showWebViewTabsViewer = false;
    });
  }

  void _closeWebViewTab(WebViewTab webViewTab) {
    final webViewIndex = webViewTabs.indexOf(webViewTab);
    webViewTabs.remove(webViewTab);
    if (currentTabIndex > webViewIndex) {
      currentTabIndex--;
    }
    if (webViewTabs.isEmpty) {
      webViewTabs.add(createWebViewTab());
      currentTabIndex = 0;
    }
    setState(() {
      currentTabIndex = max(0, min(webViewTabs.length - 1, currentTabIndex));
    });
  }

  void _closeAllWebViewTabs() {
    webViewTabs.clear();
    webViewTabs.add(createWebViewTab());
    setState(() {
      currentTabIndex = 0;
    });
  }

  changeBrowserChainId_(int chainId, String rpc) async {
    if (_controller == null) return;
    initJs = await changeBlockChainAndReturnInit(
      getEthereumDetailsFromChainId(chainId)['coinType'],
      chainId,
      rpc,
    );

    await _controller.removeAllUserScripts();
    await _controller.addUserScript(
      userScript: UserScript(
        source: widget.provider + initJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    );
    await _controller.reload();
  }

  Future<bool> goBack() async {
    if (_controller != null && await _controller.canGoBack()) {
      _controller.goBack();
      return true;
    }
    return false;
  }

  Future<bool> goForward() async {
    if (_controller != null && await _controller.canGoForward()) {
      _controller.goForward();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
          appBar: showWebViewTabsViewer
              ? _buildWebViewTabViewerAppBar()
              : _buildWebViewTabAppBar(),
          body: IndexedStack(
            index: showWebViewTabsViewer ? 1 : 0,
            children: [_buildWebViewTabs(), _buildWebViewTabsViewer()],
          )),
      onWillPop: () async {
        if (showWebViewTabsViewer) {
          setState(() {
            showWebViewTabsViewer = false;
          });
        } else if (await webViewTabs[currentTabIndex].canGoBack()) {
          webViewTabs[currentTabIndex].goBack();
        } else {
          return true;
        }
        return false;
      },
    );
  }
}
