import 'package:html/parser.dart' as html;
import 'transport.dart';

/// Only server-rendered error containers are classified. Static page scripts
/// contain password/captcha error translations even on a successful form GET.
FoundationException? authenticationRejection(String source) {
  final document = html.parse(source);
  final message = document
      .querySelectorAll('#showErrorTip, #msg, #formErrorTip, .errors')
      .map((e) => e.text.trim())
      .where((e) => e.isNotEmpty)
      .join(' ');
  if (message.isEmpty) return null;
  if (RegExp(
    r'已锁定|被锁定|已冻结|被禁用|locked|disabled',
    caseSensitive: false,
  ).hasMatch(message)) {
    return const FoundationException(
      'account_locked',
      '学校账号已被锁定或停用，请在学校认证页面处理后重新登录。',
    );
  }
  if (RegExp(
    r'密码.{0,8}(过期|到期)|修改密码|password.{0,12}expired',
    caseSensitive: false,
  ).hasMatch(message)) {
    return const FoundationException(
      'password_expired',
      '统一认证密码已过期，请先在学校页面修改密码，再更新本机保存的密码。',
    );
  }
  if (RegExp(r'验证码|滑块|captcha', caseSensitive: false).hasMatch(message)) {
    return const FoundationException('captcha_rejected', '学校验证码校验失败，请重试。');
  }
  if (RegExp(
    r'(密码|用户名|用户|账号|帐号).{0,12}(错误|有误|不正确|不存在|不匹配)|invalid.{0,5}credentials|incorrect.{0,12}password|bad.{0,5}credentials',
    caseSensitive: false,
  ).hasMatch(message)) {
    return const FoundationException(
      'credentials_rejected',
      '账号或密码错误，请检查并修改后重新登录。',
    );
  }
  if (RegExp(
    r'二次验证|双因子|短信|扫码|动态码|two.factor|verification required',
    caseSensitive: false,
  ).hasMatch(message)) {
    return const FoundationException(
      'interactive_login_required',
      '学校要求额外身份验证，请使用学校网页登录完成验证。',
    );
  }
  return const FoundationException(
    'login_not_completed',
    '学校未完成统一认证，请重试或使用学校网页登录。',
  );
}

const schoolServices = <String, String>{
  'academic': 'https://bkjx.wust.edu.cn/jsxsd/',
  'library': 'https://libsys.wust.edu.cn:443/meta-local/opac/cas/rosetta',
  'shuttle': 'https://portal.wust.edu.cn/shiro-cas',
  'second-class': 'https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do',
};

Uri checkedSchoolService(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null &&
      uri.scheme == 'https' &&
      !uri.authority.contains('@') &&
      uri.fragment.isEmpty &&
      schoolServices.values.any((v) => Uri.parse(v) == uri))
    return uri;
  throw const FoundationException('unsafe_service', '不支持的学校授权目标。');
}

String checkedServiceTicket(Uri callback, Uri service) {
  final tickets = callback.queryParametersAll['ticket'];
  if (callback.scheme != service.scheme ||
      callback.host != service.host ||
      callback.port != service.port ||
      callback.path != service.path ||
      callback.authority.contains('@') ||
      callback.fragment.isNotEmpty ||
      callback.queryParametersAll.keys.any((k) => k != 'ticket') ||
      tickets == null ||
      tickets.length != 1 ||
      !RegExp(r'^ST-[A-Za-z0-9._~-]+$').hasMatch(tickets.single)) {
    throw const FoundationException('unsafe_redirect', '学校授权回调不符合当前业务目标。');
  }
  return tickets.single;
}
