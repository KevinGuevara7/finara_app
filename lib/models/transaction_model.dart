class TransactionModel {
  
  int? id;
  String type;
  double amount;
  String description;

  String categoryId;
  String categoryName;

  DateTime date;
  String? imagePath;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.date,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "type": type,
        "amount": amount,
        "description": description,
        "categoryId": categoryId,
        "categoryName": categoryName,
        "date": date.toIso8601String(),
        "imagePath": imagePath,
      };

 factory TransactionModel.fromMap(Map<String, dynamic> map) {
  return TransactionModel(
    id: map["id"] ?? 0,
    type: map["type"] ?? "",
    amount: (map["amount"] as num?)?.toDouble() ?? 0.0,
    description: map["description"] ?? "",

    categoryId:
        (map["category_id"] ?? map["categoryId"] ?? 0).toString(),

    categoryName:
        map["category_name"] ??
        map["categoryName"] ??
        map["category"] ??
        "General",

   date: map["date"] != null
    ? (DateTime.tryParse(map["date"].toString()) ?? DateTime.now())
    : DateTime.now(),

    imagePath: map["imagePath"]?.toString(),
  );
}
}
