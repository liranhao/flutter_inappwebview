import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_example/main.dart';

// import 'package:sf_express_international/common/api_clients/config_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class MailWebViewPage extends StatefulWidget {
  final String url;
  final String title;

  /// 是否支持寄件服务

  MailWebViewPage({

    /// aws环境
    // this.url = "https://order.sit.sf.global/#/index?sgsUserid=IUOPUec70956bb61e4108bdb6f52d6bcb2e55&token=A3_ef54109e609cb99b9df83550bbeda90c1621247596303&lang=zh_CN&version=1.13.0&orderType=global&countryCode=SG&waybillNo=&channel=sf&appSourceId=&",
    // this.url = "https://order.sf.global/#/index?sgsUserid=IUOPUec70956bb61e4108bdb6f52d6bcb2e55&token=A3_ef54109e609cb99b9df83550bbeda90c1621247596303&lang=zh_CN&version=1.13.0&orderType=global&countryCode=SG&waybillNo=&channel=sf&appSourceId=&",
    /// 自寄点
    this.url = "https://order.sit.sf.global/#/self-mail-point?sgsUserid=pr_65d389c3258c57d1f9af6174b56abea5&token=pr_65d389c3258c57d1f9af6174b56abea5&lang=zh_CN&version=1.13.0&currentEnv=INT-APP&countryCode=SG",
    // this.url = "https://www.baidu.com",
    // this.url = "https://github.com/flutter",
    this.title = "测试吧",
  });

  @override
  _MailWebViewPageState createState() => _MailWebViewPageState();
}

class _MailWebViewPageState extends State<MailWebViewPage>
    with WidgetsBindingObserver {
  InAppWebViewController _webViewController;
  bool _isShowErrorPage = false;
  bool _isLoadError = false;

  /// 网页加载完成
  bool isLoadFinish = false;

  /// 是否显示弹窗
  bool isShowDialog = false;

  /// 显示webview
  bool isShowWebview = Platform.isIOS ? true : false;
  double bottom = 0.0;
  String title;
  String url;

  /// 当前最新的url
  String _currentUrl;

  _MailWebViewPageState();

  @override
  void initState() {
    super.initState();
    title = widget.title;
    url = widget.url;

    print("重新进来了");
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      // showAlertDialog();
      getNetworkStatus();
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context != null) {

        bottom = MediaQuery.of(context).viewInsets.bottom;
        print("键盘弹起了 打印bottom = $bottom");
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    // LoadingUtil.hideLoading();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Color(0xFFFFFFFF),
        brightness: Brightness.light,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        // centerTitle: true,
        // titleSpacing: 0,
        title: Container(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Color(0xff333333),
            ),
          ),
        ),
      ),
      drawer: myDrawer(context: context),
      body: WillPopScope(
        onWillPop: willPopCallback,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Offstage(
                // offstage: !isShowWebview,
                offstage: false,
                child: Container(
                  margin: EdgeInsets.only(bottom: bottom),
                  child: InAppWebView(
                    initialUrl: url,
                    initialOptions: InAppWebViewGroupOptions(
                      crossPlatform: InAppWebViewOptions(
                        debuggingEnabled: true,
                        verticalScrollBarEnabled: false,
                        horizontalScrollBarEnabled: false,
                        transparentBackground: true,
                        // clearCache: true,
                      ),
                      android: AndroidInAppWebViewOptions(
                        /// 打开这个则不能使用，Offstage
                        useHybridComposition: true,
                        blockNetworkImage: false,
                        mixedContentMode:
                            AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                        allowUniversalAccessFromFileURLs: true,
                      ),
                    ),
                    onWebViewCreated: (InAppWebViewController controller) {
                      _webViewController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'flutter_sfgo',
                        callback: javaScriptHandlerCallback,
                      );
                    },
                    androidOnGeolocationPermissionsShowPrompt:
                        (InAppWebViewController controller,
                            String origin) async {
                      return GeolocationPermissionShowPromptResponse(
                        origin: origin,
                        allow: true,
                        retain: false,
                      );
                    },
                    onLoadStart:
                        (InAppWebViewController controller, String url) {
                      print("onLoadStart $url");
                      onPageStarted(url);
                    },
                    onLoadStop:
                        (InAppWebViewController controller, String url) async {
                      print("onLoadStop $url");
                      onPageFinished(url);
                    },
                    onLoadError: (InAppWebViewController controller, String url,
                        int code, String description) {
                      print("onLoadError url $url");
                      print("onLoadError code $code");
                      print("onLoadError description $description");
                      if (description == "net::ERR_INTERNET_DISCONNECTED") {
                        print("我是网络错误");
                        _isLoadError = true;
                      }
                    },
                    shouldInterceptAjaxRequest:
                        (InAppWebViewController controller,
                            AjaxRequest ajaxRequest) {
                      return Future.value(ajaxRequest);
                    },
                    onAjaxReadyStateChange: (InAppWebViewController controller,
                        AjaxRequest ajaxRequest) {
                      debugPrint(
                          "onAjaxReadyStateChange:" + ajaxRequest.toString());
//                  ajaxRequest.readyState = AjaxRequestReadyState.DONE;
//                  ajaxRequest.status = 200;
//                  ajaxRequest.responseText = '拦截返回值';
                      return Future.value(AjaxRequestAction.PROCEED);
                    },
                    shouldInterceptFetchRequest:
                        (InAppWebViewController controller,
                            FetchRequest fetchRequest) {
                      return Future.value(fetchRequest);
                    },
                  ),
                ),
              ),
              Offstage(
                offstage: !_isShowErrorPage,
                child: Container(
                  child: Text("显示错误页面",
                      style: TextStyle(
                        fontSize: 44,
                        color: Color(0xff333333),
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reloadData() async {
    await _webViewController?.reload();
  }

  void dismissErrorPage() {
    setState(() {
      _isShowErrorPage = false;
    });
  }

  onPageStarted(url) {
    // dismissErrorPage();
    _isLoadError = false;
    _currentUrl = url;
    if (!isShowDialog) {
      // LoadingUtil.showLoading(userInteractions: true);
    }
  }

  onPageFinished(url) {
    isLoadFinish = true;
    if (_isLoadError) {
      showErrorPage();
    } else {
      dismissErrorPage();
    }
    if (!isShowWebview) {
      setState(() {
        isShowWebview = true;
      });
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      // LoadingUtil.hideLoading();
    });
  }

  /// 显示错误页面
  void showErrorPage() {
    // LoadingUtil.hideLoading();
    setState(() {
      _isShowErrorPage = true;
    });
  }

  /// 获取网络状态
  void getNetworkStatus() async {
    // bool isConnected = await NetWorkUtil.isConnected();
    // if (!isConnected) {
    //   showErrorPage();
    // }
  }

  javaScriptHandlerCallback(List<dynamic> arguments) {
    try {
      print("接收sfgo的调用 ${arguments}");
      String arg = arguments.first;
      // SFGOJavascriptChannelCallbackModel titleModel =
      //     SFGOJavascriptChannelCallbackModel.fromJson(json.decode(arg));

      // setState(() {});
      // return returnParas;
      return "34";
    } catch (e) {
      // LogUtil.e(e, tag: "BaseInAppWebView");
    }
  }

  // dynamic handleJSCallWebView(
  //     SFGOJavascriptChannelCallbackModel sfgoJavascriptChannelCallbackModel) {
  //   switch (sfgoJavascriptChannelCallbackModel.type) {
  //     case SFGOJavascriptChannelTypeName.SEND_PARCEL:
  //       break;
  //
  //     /// 改变title
  //     case SFGOJavascriptChannelTypeName.PAGE_CHANGE:
  //       break;
  //
  //     /// 自寄点打电话
  //     case SFGOJavascriptChannelTypeName.CALL_UP:
  //       {
  //         selectPhoneNum(sfgoJavascriptChannelCallbackModel.phoneNums);
  //       }
  //       break;
  //
  //     /// 登出
  //     case SFGOJavascriptChannelTypeName.LOGOUT_DIRECTLY:
  //
  //       /// todo: 考虑是否要登出，登出是否要弹出toast
  //       HomeManager.unbindFirebaseToken();
  //       LoginUser.logout(context);
  //       break;
  //     case SFGOJavascriptChannelTypeName.GET_LOCATION:
  //       return getLocation();
  //       break;
  //     default:
  //       break;
  //   }
  // }

  void _goBack() async {
    if (_webViewController != null) {
      /// H5能后退则后退，不能后退就关闭页面，isIndex表示首页
      var isIndex =
          await _webViewController.evaluateJavascript(source: "nativeGoBack()");
      print("打印值后退值 isIndex = $isIndex");

      if (isIndex != null && isIndex) {
        Navigator.pop(context);
      } else {
        /// 跳转到usshipweb这个页面后，也要允许点击返回键
        if (await this._webViewController.canGoBack() &&
            _currentUrl.contains("usshipweb.sf-express.com")) {
          this._webViewController.goBack();
        }
      }
    }
  }

  /// 拦截返回按键，返回true时，出栈
  Future<bool> willPopCallback() async {
    // FocusScope.of(context).requestFocus(FocusNode());
    print("返回按键");
    /// 隐藏键盘
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    // if (_webViewController != null) {
    //   /// H5能后退则后退，不能后退就关闭页面
    //   var isIndex =
    //       await _webViewController.evaluateJavascript(source: "nativeGoBack()");
    //
    //   if (isIndex != null && isIndex) {
    //     return true;
    //   } else {
    //     /// 跳转到usshipweb这个页面后，也要允许点击返回键
    //     if (await this._webViewController.canGoBack() &&
    //         _currentUrl.contains("usshipweb.sf-express.com")) {
    //       this._webViewController.goBack();
    //     }
    //     return false;
    //   }
    // }
    return false;
  }
}
