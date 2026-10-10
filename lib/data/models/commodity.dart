import 'package:decimal/decimal.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import 'amount.dart';
import 'json_utils.dart';

/// `GET /api/commodities` item (`CommodityListItem`).
class Commodity {
  const Commodity({
    required this.name,
    required this.precision,
    this.prefix,
    this.suffix,
    this.rounding,
    this.group,
    required this.totalAmount,
    this.latestPriceDate,
    this.latestPriceAmount,
    this.latestPriceCommodity,
  });

  factory Commodity.fromJson(JsonMap m) => Commodity(
    name: reqString(m, 'name'),
    precision: m['precision'] == null ? 2 : reqInt(m, 'precision'),
    prefix: optString(m, 'prefix'),
    suffix: optString(m, 'suffix'),
    rounding: optString(m, 'rounding'),
    group: optString(m, 'group'),
    totalAmount: parseDecimalOrNull(m['total_amount'], 'total_amount') ?? Decimal.zero,
    latestPriceDate: optNaiveDateTime(m, 'latest_price_date'),
    latestPriceAmount: parseDecimalOrNull(m['latest_price_amount'], 'latest_price_amount'),
    latestPriceCommodity: optString(m, 'latest_price_commodity'),
  );

  final String name;

  /// Display decimals.
  final int precision;

  /// Display symbols, e.g. `¥` / `$`.
  final String? prefix;
  final String? suffix;

  /// `RoundDown` / `RoundUp` (zhang maps them to bigdecimal `HalfDown` /
  /// `HalfUp`; the server default is `RoundDown`).
  final String? rounding;
  final String? group;

  /// Sum held in Assets + Liabilities.
  final Decimal totalAmount;

  /// Latest price **to the operating currency** only.
  final DateTime? latestPriceDate;
  final Decimal? latestPriceAmount;
  final String? latestPriceCommodity;

  /// Formats [value] of this commodity with its precision, rounding and
  /// prefix/suffix.
  String format(Decimal value, {bool signed = false}) => formatMoney(
    value,
    name,
    precision: precision,
    signed: signed,
    prefix: prefix,
    suffix: suffix,
    halfDown: rounding != 'RoundUp',
  );
}

/// A lot in `GET /api/commodities/{name}`.
class CommodityLot {
  const CommodityLot({
    required this.account,
    required this.amount,
    this.cost,
    this.price,
    this.acquisitionDate,
  });

  factory CommodityLot.fromJson(JsonMap m) => CommodityLot(
    account: reqString(m, 'account'),
    amount: parseDecimal(m['amount'], 'lot.amount'),
    cost: Amount.fromJsonOrNull(m['cost']),
    price: Amount.fromJsonOrNull(m['price']),
    acquisitionDate: m['acquisition_date'] == null
        ? null
        : ZhangDates.parseDate(reqString(m, 'acquisition_date')),
  );

  final String account;
  final Decimal amount;
  final Amount? cost;
  final Amount? price;

  /// Local midnight of the `YYYY-MM-DD` acquisition date.
  final DateTime? acquisitionDate;
}

/// A price directive in `GET /api/commodities/{name}`.
class CommodityPrice {
  const CommodityPrice({required this.datetime, required this.amount});

  factory CommodityPrice.fromJson(JsonMap m) =>
      CommodityPrice(datetime: reqNaiveDateTime(m, 'datetime'), amount: Amount.fromJson(m['amount']));

  final DateTime datetime;
  final Amount amount;
}

/// `GET /api/commodities/{name}`.
class CommodityDetail {
  const CommodityDetail({required this.info, this.lots = const [], this.prices = const []});

  factory CommodityDetail.fromJson(Object? json) {
    final m = asMap(json, 'commodity detail');
    return CommodityDetail(
      info: Commodity.fromJson(asMap(m['info'], 'info')),
      lots: parseList(m['lots'] ?? const [], CommodityLot.fromJson, 'lots'),
      prices: parseList(m['prices'] ?? const [], CommodityPrice.fromJson, 'prices')
        ..sort((a, b) => a.datetime.compareTo(b.datetime)),
    );
  }

  final Commodity info;
  final List<CommodityLot> lots;

  /// Chronological.
  final List<CommodityPrice> prices;
}
