import SwiftUI
import LimitsCore

struct BillingCard: View {
    var snapshot: VerifiedBilling?
    var now: Date
    var openSubscription: () -> Void

    private func formatted(_ date: Date) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "ru_RU")
        format.dateFormat = "d MMMM yyyy"
        return format.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Следующая оплата", systemImage: "calendar")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            if let snapshot, let date = snapshot.renewalDate, let days = snapshot.daysRemaining(at: now), days >= 0 {
                Text(formatted(date)).font(.system(size: 18, weight: .semibold))
                Text(days == 0 ? "Сегодня" : "До продления: \(days) дн.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text("Проверено \(formatted(Date(timeIntervalSince1970: snapshot.checkedAt))) в ChatGPT.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                if snapshot.needsVerification(at: now) {
                    Text("Дату нужно сверить с подпиской.").font(.system(size: 11)).foregroundStyle(.orange)
                }
            } else if snapshot != nil {
                Text("Ожидает обновления").font(.system(size: 18, weight: .semibold))
            } else {
                Text("Дата недоступна").font(.system(size: 18, weight: .semibold))
            }
            Button(action: openSubscription) {
                Label("Управление подпиской", systemImage: "arrow.up.right.square")
            }.controlSize(.small)
                .help("Открыть настройки подписки в браузере по умолчанию")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}
