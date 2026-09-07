"""预置分类数据（首次启动时写入）"""

PRESET_CATEGORIES = [
    # (name, type, icon, sort)
    ("餐饮", "expense", "🍜", 1),
    ("交通", "expense", "🚌", 2),
    ("购物", "expense", "🛍️", 3),
    ("居住", "expense", "🏠", 4),
    ("娱乐", "expense", "🎮", 5),
    ("医疗", "expense", "💊", 6),
    ("教育", "expense", "📚", 7),
    ("通讯", "expense", "📱", 8),
    ("人情", "expense", "🎁", 9),
    ("宠物", "expense", "🐱", 10),
    ("其他支出", "expense", "📦", 99),
    ("工资", "income", "💰", 1),
    ("奖金", "income", "🏆", 2),
    ("兼职", "income", "💼", 3),
    ("理财收益", "income", "📈", 4),
    ("二手闲置", "income", "♻️", 5),
    ("红包", "income", "🧧", 6),
    ("其他收入", "income", "💵", 99),
]
