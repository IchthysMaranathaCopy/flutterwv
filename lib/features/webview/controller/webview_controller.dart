import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';

class WebViewControllerManager {
  static WebViewController initController({
    required Function(bool) setLoading,
  }) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => setLoading(true),
        onPageFinished: (url) => setLoading(false),
        onNavigationRequest: (request) async {
          final url = request.url;


          if (url.contains('instagram.com/ogrencikariyeri')) {
            await launchUrl(
              Uri.parse('instagram://user?username=ogrencikariyeri'),
              mode: LaunchMode.externalApplication,
            );
            return NavigationDecision.prevent;
          }


          if (url.contains('twitter.com/ogrencikariyeri') ||
              url.contains('x.com/ogrencikariyeri')) {
            await launchUrl(
              Uri.parse('twitter://user?screen_name=ogrencikariyeri'),
              mode: LaunchMode.externalApplication,
            );
            return NavigationDecision.prevent;
          }


          if (url.contains('facebook.com/ogrencikariyeri')) {
            await launchUrl(
              Uri.parse('fb://facewebmodal/f?href=$url'),
              mode: LaunchMode.externalApplication,
            );
            return NavigationDecision.prevent;
          }


          if (url.contains('linkedin.com/company/ogrenci-kariyeri')) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            return NavigationDecision.prevent;
          }


          if (url.contains('youtube.com/@ogrencikariyeri')) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            return NavigationDecision.prevent;
          }


          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(AppConstants.baseUrl));
  }
}
