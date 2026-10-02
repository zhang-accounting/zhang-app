import 'package:flutter/material.dart';

import '../data/models/account.dart';

/// Local keyword → Material icon mapping for category / account icons
/// (docs/decisions.md §4: icons live only on the device, nothing is written
/// to the ledger).
///
/// English keywords are matched against the *words* of an account segment
/// (`PersonalDiet` → `personal`, `diet`): a word matches a keyword when it
/// equals it or, for keywords of 4+ letters, starts with it (`transport`
/// matches `Transportation`). Word matching avoids false hits such as `car`
/// in `CreditCard` or `fee` in `Coffee`. Chinese keywords are plain substring
/// matches (Chinese has no word boundaries).
class _IconRule {
  const _IconRule(this.icon, this.en, [this.zh = const []]);

  final IconData icon;
  final List<String> en;
  final List<String> zh;
}

/// First matching rule wins, so more specific rules come first.
const List<_IconRule> _rules = [
  // Food & drink.
  _IconRule(Icons.local_cafe, ['coffee', 'cafe', 'starbucks', 'tea', 'drink', 'drinks', 'beverage'], ['咖啡', '奶茶', '饮料', '茶']),
  _IconRule(Icons.local_grocery_store, ['grocery', 'groceries', 'supermarket', 'market'], ['超市', '买菜', '菜场', '生鲜']),
  _IconRule(Icons.bakery_dining, ['snack', 'snacks', 'bakery', 'dessert', 'fruit'], ['零食', '水果', '甜品', '面包']),
  _IconRule(Icons.restaurant, [
    'food', 'diet', 'dining', 'dine', 'meal', 'meals', 'restaurant', 'lunch', 'dinner', 'breakfast',
    'eat', 'eating', 'takeout', 'takeaway', 'delivery',
  ], ['餐', '饭', '食', '吃', '外卖', '饮']),
  // Getting around.
  _IconRule(Icons.local_taxi, ['taxi', 'uber', 'lyft', 'didi', 'cab'], ['打车', '出租', '滴滴']),
  _IconRule(Icons.local_gas_station, ['fuel', 'petrol', 'gasoline'], ['加油', '油费']),
  _IconRule(Icons.local_parking, ['parking', 'toll', 'tolls'], ['停车', '过路']),
  _IconRule(Icons.directions_car, ['car', 'cars', 'auto', 'vehicle'], ['汽车', '养车', '车']),
  _IconRule(Icons.flight, ['flight', 'flights', 'airfare', 'travel', 'trip', 'trips', 'vacation', 'holiday', 'hotel'], ['旅行', '旅游', '机票', '酒店', '度假']),
  _IconRule(Icons.directions_bus, [
    'transport', 'transit', 'bus', 'metro', 'subway', 'train', 'rail', 'commute', 'commuting',
  ], ['交通', '地铁', '公交', '出行', '火车', '高铁']),
  // Home & bills.
  _IconRule(Icons.bolt, ['utility', 'utilities', 'electric', 'electricity', 'power', 'water', 'heating'], ['水电', '电费', '水费', '燃气', '暖气', '物业']),
  _IconRule(Icons.phone_android, ['phone', 'mobile', 'cellular', 'internet', 'telecom', 'broadband'], ['话费', '通讯', '网费', '宽带', '手机']),
  _IconRule(Icons.chair, ['furniture', 'household', 'appliance', 'appliances'], ['家具', '家居', '日用', '家电']),
  _IconRule(Icons.home, ['rent', 'housing', 'house', 'home', 'mortgage', 'apartment'], ['房租', '房贷', '住房', '居住', '住', '家']),
  // Shopping & personal.
  _IconRule(Icons.checkroom, ['clothing', 'clothes', 'apparel', 'fashion', 'shoes', 'garment'], ['服饰', '服装', '衣', '鞋', '服']),
  _IconRule(Icons.spa, ['beauty', 'cosmetics', 'haircut', 'salon', 'makeup'], ['美容', '美妆', '理发', '护肤']),
  _IconRule(Icons.devices, ['electronics', 'gadget', 'gadgets', 'digital', 'computer'], ['数码', '电子', '电脑']),
  _IconRule(Icons.shopping_bag, ['shopping', 'shop', 'store', 'amazon', 'taobao'], ['购物', '网购', '淘宝', '京东']),
  // Health, sport, fun.
  _IconRule(Icons.local_hospital, ['medical', 'medicine', 'health', 'healthcare', 'hospital', 'doctor', 'dental', 'pharmacy', 'clinic'], ['医疗', '医', '药', '健康', '看病']),
  _IconRule(Icons.fitness_center, ['sport', 'sports', 'gym', 'fitness', 'workout', 'exercise'], ['运动', '健身', '体育']),
  _IconRule(Icons.movie, ['movie', 'movies', 'cinema', 'film', 'theatre', 'theater', 'concert'], ['电影', '演出', '影院']),
  _IconRule(Icons.sports_esports, ['game', 'games', 'gaming'], ['游戏']),
  _IconRule(Icons.subscriptions, ['subscription', 'subscriptions', 'software', 'streaming', 'membership'], ['订阅', '会员', '软件']),
  _IconRule(Icons.celebration, ['entertainment', 'fun', 'leisure', 'hobby', 'hobbies', 'party'], ['娱乐', '休闲', '聚会']),
  // Family & social.
  _IconRule(Icons.school, ['education', 'school', 'tuition', 'course', 'courses', 'book', 'books', 'learning', 'study', 'training'], ['教育', '学费', '培训', '书', '学习', '课程']),
  _IconRule(Icons.child_care, ['kid', 'kids', 'child', 'children', 'baby', 'childcare'], ['孩子', '育儿', '母婴', '宝宝']),
  _IconRule(Icons.pets, ['pet', 'pets', 'dog', 'cat'], ['宠物', '猫', '狗']),
  _IconRule(Icons.card_giftcard, ['gift', 'gifts', 'present', 'presents'], ['礼物', '礼金', '红包', '礼']),
  _IconRule(Icons.volunteer_activism, ['donation', 'donations', 'charity'], ['捐赠', '慈善', '捐']),
  _IconRule(Icons.groups, ['social', 'friends'], ['社交', '人情']),
  // Money matters.
  _IconRule(Icons.health_and_safety, ['insurance'], ['保险']),
  _IconRule(Icons.request_quote, ['tax', 'taxes'], ['税']),
  _IconRule(Icons.receipt_long, ['fee', 'fees', 'commission', 'charge', 'charges'], ['手续费', '佣金']),
  _IconRule(Icons.account_balance, ['bank', 'banking'], ['银行']),
  _IconRule(Icons.percent, ['interest'], ['利息']),
  _IconRule(Icons.payments, ['salary', 'salaries', 'wage', 'wages', 'payroll', 'paycheck'], ['工资', '薪', '月薪']),
  _IconRule(Icons.emoji_events, ['bonus', 'award', 'prize'], ['奖金', '年终', '奖']),
  _IconRule(Icons.trending_up, ['dividend', 'dividends', 'investment', 'investments', 'invest', 'stock', 'stocks', 'capital'], ['投资', '股息', '分红', '理财', '股票']),
  _IconRule(Icons.work_outline, ['freelance', 'remuneration', 'royalty', 'royalties', 'publisher', 'consulting', 'side'], ['兼职', '稿费', '劳务', '副业', '外快']),
  _IconRule(Icons.replay, ['refund', 'refunds', 'reimbursement', 'cashback', 'rebate'], ['退款', '报销', '返现']),
  _IconRule(Icons.savings, ['saving', 'savings', 'deposit'], ['储蓄', '存款']),
  _IconRule(Icons.credit_card, ['card', 'credit', 'creditcard'], ['信用卡']),
  _IconRule(Icons.money, ['cash', 'wallet'], ['现金', '钱包']),
];

final _wordSplitter = RegExp(r'[^A-Za-z]+|(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])');

/// Lower-cased English words of [text] (`PersonalDiet` → `personal`, `diet`).
List<String> _words(String text) => [
  for (final w in text.split(_wordSplitter))
    if (w.isNotEmpty) w.toLowerCase(),
];

bool _wordMatches(String word, String keyword) =>
    word == keyword || (keyword.length >= 4 && word.startsWith(keyword));

/// The icon of the first rule matching [text] (an account segment or an
/// alias), or `null`. Later words win over earlier ones, so
/// `RemunerationTax` maps to the tax icon.
IconData? matchCategoryIcon(String text) {
  for (final rule in _rules) {
    for (final zh in rule.zh) {
      if (text.contains(zh)) return rule.icon;
    }
  }
  final words = _words(text).reversed.toList();
  for (final word in words) {
    for (final rule in _rules) {
      for (final keyword in rule.en) {
        if (_wordMatches(word, keyword)) return rule.icon;
      }
    }
  }
  return null;
}

/// Default icon of an account type (docs/design-research.md §2.7).
IconData accountTypeIcon(AccountType? type) => switch (type) {
  AccountType.assets => Icons.account_balance_wallet_outlined,
  AccountType.liabilities => Icons.credit_card,
  AccountType.equity => Icons.balance,
  AccountType.income => Icons.trending_up,
  AccountType.expenses => Icons.sell_outlined,
  null => Icons.folder_outlined,
};

/// Icon for a category (or any account): tries [alias], then the account
/// segments from the most specific one up to the second level, then
/// [childNames] (e.g. `Expenses:PersonalDiet` has no keyword of its own but a
/// child `…:Lunch` does), and finally the account type's default icon.
IconData categoryIcon(String accountName, {String? alias, Iterable<String> childNames = const []}) {
  if (alias != null && alias.isNotEmpty) {
    final icon = matchCategoryIcon(alias);
    if (icon != null) return icon;
  }
  final segments = accountName.split(':');
  for (var i = segments.length - 1; i >= 1; i--) {
    final icon = matchCategoryIcon(segments[i]);
    if (icon != null) return icon;
  }
  for (final child in childNames) {
    final icon = matchCategoryIcon(child.split(':').last);
    if (icon != null) return icon;
  }
  return accountTypeIcon(AccountType.ofAccount(accountName));
}
