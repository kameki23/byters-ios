import SwiftUI

// MARK: - Bank Data

struct JapaneseBank: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: BankCategory
}

enum BankCategory: String, CaseIterable {
    case mega = "メガバンク"
    case yucho = "ゆうちょ銀行"
    case net = "ネット銀行"
    case trust = "信託銀行"
    case regional = "地方銀行"
    case shinkin = "信用金庫"
    case other = "その他"

    var icon: String {
        switch self {
        case .mega: return "building.columns.fill"
        case .yucho: return "envelope.fill"
        case .net: return "globe"
        case .trust: return "lock.shield.fill"
        case .regional: return "map.fill"
        case .shinkin: return "person.3.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct BankDataProvider {
    static let banks: [JapaneseBank] = {
        var list: [JapaneseBank] = []

        // メガバンク
        let mega: [String] = [
            "三菱UFJ銀行", "三井住友銀行", "みずほ銀行",
            "りそな銀行", "埼玉りそな銀行"
        ]
        list += mega.map { JapaneseBank(name: $0, category: .mega) }

        // ゆうちょ銀行
        list.append(JapaneseBank(name: "ゆうちょ銀行", category: .yucho))

        // ネット銀行
        let net: [String] = [
            "PayPay銀行", "楽天銀行", "住信SBIネット銀行",
            "ソニー銀行", "auじぶん銀行", "イオン銀行",
            "セブン銀行", "GMOあおぞらネット銀行",
            "UI銀行", "みんなの銀行"
        ]
        list += net.map { JapaneseBank(name: $0, category: .net) }

        // 信託銀行
        let trust: [String] = [
            "三菱UFJ信託銀行", "三井住友信託銀行",
            "みずほ信託銀行", "SMBC信託銀行"
        ]
        list += trust.map { JapaneseBank(name: $0, category: .trust) }

        // 地方銀行
        let regional: [String] = [
            // 北海道・東北
            "北海道銀行", "北洋銀行", "青森銀行", "みちのく銀行",
            "秋田銀行", "北都銀行", "荘内銀行", "山形銀行",
            "岩手銀行", "東北銀行", "七十七銀行", "東邦銀行",
            // 関東
            "群馬銀行", "足利銀行", "常陽銀行", "筑波銀行",
            "武蔵野銀行", "千葉銀行", "千葉興業銀行",
            "きらぼし銀行", "横浜銀行", "東日本銀行",
            "東京スター銀行",
            // 中部
            "第四北越銀行", "北陸銀行", "富山銀行", "北國銀行",
            "福井銀行", "山梨中央銀行", "八十二銀行", "長野銀行",
            "静岡銀行", "スルガ銀行", "清水銀行",
            "大垣共立銀行", "十六銀行",
            "愛知銀行", "名古屋銀行", "中京銀行",
            "百五銀行", "三十三銀行",
            // 関西
            "滋賀銀行", "京都銀行", "関西みらい銀行",
            "池田泉州銀行", "南都銀行", "紀陽銀行", "但馬銀行",
            // 中国・四国
            "鳥取銀行", "山陰合同銀行", "中国銀行",
            "広島銀行", "山口銀行",
            "阿波銀行", "百十四銀行", "伊予銀行", "四国銀行",
            // 九州・沖縄
            "福岡銀行", "筑邦銀行", "西日本シティ銀行",
            "北九州銀行", "佐賀銀行", "十八親和銀行",
            "肥後銀行", "大分銀行", "宮崎銀行",
            "鹿児島銀行", "琉球銀行", "沖縄銀行"
        ]
        list += regional.map { JapaneseBank(name: $0, category: .regional) }

        // 信用金庫（主要）
        let shinkin: [String] = [
            "京都中央信用金庫", "城南信用金庫", "多摩信用金庫",
            "岡崎信用金庫", "埼玉縣信用金庫", "川崎信用金庫",
            "横浜信用金庫", "西武信用金庫", "大阪信用金庫",
            "尼崎信用金庫", "芝信用金庫", "朝日信用金庫"
        ]
        list += shinkin.map { JapaneseBank(name: $0, category: .shinkin) }

        // その他
        let others: [String] = [
            "SBI新生銀行", "あおぞら銀行", "商工組合中央金庫",
            "農林中央金庫", "JAバンク", "労働金庫"
        ]
        list += others.map { JapaneseBank(name: $0, category: .other) }

        return list
    }()
}

// MARK: - Bank Selection View

struct BankSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedBankName: String
    @State private var searchText = ""
    @State private var showCustomInput = false
    @State private var customBankName = ""

    private var filteredBanks: [JapaneseBank] {
        if searchText.isEmpty {
            return BankDataProvider.banks
        }
        return BankDataProvider.banks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedBanks: [(BankCategory, [JapaneseBank])] {
        let grouped = Dictionary(grouping: filteredBanks) { $0.category }
        return BankCategory.allCases.compactMap { category in
            guard let banks = grouped[category], !banks.isEmpty else { return nil }
            return (category, banks)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty && filteredBanks.isEmpty {
                    Section {
                        Text("「\(searchText)」に一致する銀行が見つかりません")
                            .foregroundColor(.secondary)
                            .font(.subheadline)

                        Button {
                            selectedBankName = searchText
                            dismiss()
                        } label: {
                            Label("「\(searchText)」で登録する", systemImage: "plus.circle.fill")
                        }
                    }
                }

                ForEach(groupedBanks, id: \.0) { category, banks in
                    Section {
                        ForEach(banks) { bank in
                            Button {
                                selectedBankName = bank.name
                                dismiss()
                            } label: {
                                HStack {
                                    Text(bank.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedBankName == bank.name {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }

                Section {
                    Button {
                        showCustomInput = true
                    } label: {
                        Label("その他（手入力）", systemImage: "pencil")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "銀行名を検索")
            .navigationTitle("銀行を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("銀行名を入力", isPresented: $showCustomInput) {
                TextField("銀行名", text: $customBankName)
                Button("登録") {
                    if !customBankName.isEmpty {
                        selectedBankName = customBankName
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {
                    customBankName = ""
                }
            } message: {
                Text("リストにない銀行名を入力してください")
            }
        }
    }
}
