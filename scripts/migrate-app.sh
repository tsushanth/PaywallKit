#!/bin/bash
# PaywallKit Migration Script
# Adds PaywallKit SPM dependency, RemotePaywallView, PromoCodeManager, and WinbackOfferView
# Usage: ./migrate-app.sh <project-dir> <app-name> <app-id> <product-ids-comma-separated>
#
# Example: ./migrate-app.sh /path/to/fitpulse FitPulse fitpulse "com.appfactory.fitpulse.premium.monthly,com.appfactory.fitpulse.premium.yearly,com.appfactory.fitpulse.premium.lifetime"

set -e

PROJECT_DIR="$1"
APP_NAME="$2"
APP_ID="$3"    # lowercase identifier for PaywallKit API (e.g., "fitpulse")
PRODUCT_IDS="$4"
PAYWALLKIT_REPO="https://github.com/tsushanth/PaywallKit"

if [ -z "$PROJECT_DIR" ] || [ -z "$APP_NAME" ] || [ -z "$APP_ID" ] || [ -z "$PRODUCT_IDS" ]; then
  echo "Usage: $0 <project-dir> <app-name> <app-id> <product-ids>"
  exit 1
fi

echo "🚀 Migrating $APP_NAME to PaywallKit..."
echo "   Dir: $PROJECT_DIR"
echo "   App ID: $APP_ID"
echo "   Products: $PRODUCT_IDS"

# Convert comma-separated product IDs to Swift array string
IFS=',' read -ra IDS <<< "$PRODUCT_IDS"
SWIFT_IDS=""
for id in "${IDS[@]}"; do
  id=$(echo "$id" | xargs)  # trim whitespace
  SWIFT_IDS="$SWIFT_IDS\"$id\", "
done
SWIFT_IDS="${SWIFT_IDS%, }"  # remove trailing comma

# ============================================================================
# Step 1: Add PaywallKit SPM dependency to Xcode project
# ============================================================================
echo ""
echo "📦 Step 1: Adding PaywallKit SPM dependency..."

# Find the .xcodeproj
XCODEPROJ=$(find "$PROJECT_DIR" -maxdepth 2 -name "*.xcodeproj" -not -path "*/Pods/*" | head -1)
if [ -z "$XCODEPROJ" ]; then
  echo "❌ No .xcodeproj found in $PROJECT_DIR"
  exit 1
fi
echo "   Project: $XCODEPROJ"

# Check if PaywallKit already exists in the project
if grep -q "PaywallKit" "$XCODEPROJ/project.pbxproj" 2>/dev/null; then
  echo "   ⚠️  PaywallKit already in project, skipping SPM step"
else
  # Use xcodebuild to add SPM package (this is the most reliable way)
  # For now we'll use the swift package resolve approach
  echo "   Adding via xcodebuild..."

  # Check if Package.resolved exists
  RESOLVED="$XCODEPROJ/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  if [ -f "$RESOLVED" ] && grep -q "PaywallKit" "$RESOLVED"; then
    echo "   ⚠️  Already in Package.resolved"
  else
    echo "   ℹ️  PaywallKit SPM needs to be added manually or via Xcode"
    echo "   Run: xcode-select -p && open $XCODEPROJ"
    echo "   Then: File > Add Package Dependencies > $PAYWALLKIT_REPO"
  fi
fi

# ============================================================================
# Step 2: Find the source directory
# ============================================================================
# Find Swift source files directory
SRC_DIR=$(find "$PROJECT_DIR" -maxdepth 3 -name "*App.swift" -not -path "*/Pods/*" -not -path "*/.build/*" | head -1 | xargs dirname)
if [ -z "$SRC_DIR" ]; then
  echo "❌ No App.swift found"
  exit 1
fi
APP_SWIFT=$(find "$SRC_DIR" -maxdepth 1 -name "*App.swift" | head -1)
echo "   Source dir: $SRC_DIR"
echo "   App file: $APP_SWIFT"

# ============================================================================
# Step 3: Create RemotePaywallView
# ============================================================================
echo ""
echo "📱 Step 3: Creating RemotePaywallView..."

PAYWALL_FILE="$SRC_DIR/RemotePaywallView.swift"
if [ -f "$PAYWALL_FILE" ]; then
  echo "   ⚠️  RemotePaywallView already exists, skipping"
else
cat > "$PAYWALL_FILE" << SWIFT
import SwiftUI
import PaywallKit

struct RemotePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var triggerSource: String = "unknown"
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        PaywallKit.PaywallView(
            appId: "$APP_ID",
            placement: PromoCodeManager.shared.activeCode != nil ? "promo_code_onboarding" : "app_open",
            appName: "$APP_NAME Premium",
            features: [],
            products: store.paywallProducts,
            theme: PaywallTheme(accent: Color.accentColor),
            showWinback: true,
            onPurchase: { productId in
                let result = await store.purchase(productId: productId)
                if case .purchased = result {
                    dismiss()
                    return true
                }
                return false
            },
            onRestore: {
                await store.restore()
                await StoreManager.shared.refreshSubscriptionStatus()
                if StoreManager.shared.isPremium {
                    dismiss()
                }
            },
            onDismiss: {
                PaywallCoordinator.shared.trackDismiss()
                dismiss()
            }
        )
        .task {
            if store.paywallProducts.isEmpty {
                await store.loadProducts()
            }
        }
    }
}
SWIFT
echo "   ✅ Created $PAYWALL_FILE"
fi

# ============================================================================
# Step 4: Create PaywallCoordinator (winback support)
# ============================================================================
echo ""
echo "🔄 Step 4: Creating PaywallCoordinator..."

COORDINATOR_FILE="$SRC_DIR/PaywallCoordinator.swift"
if [ -f "$COORDINATOR_FILE" ]; then
  echo "   ⚠️  PaywallCoordinator already exists, skipping"
else
cat > "$COORDINATOR_FILE" << 'SWIFT'
import SwiftUI
import PaywallKit

@MainActor
class PaywallCoordinator: ObservableObject {
    static let shared = PaywallCoordinator()

    @Published var showWinback = false

    private let dismissCountKey = "pwkit_paywall_dismiss_count"
    private let lastDismissKey = "pwkit_last_paywall_dismiss"
    private let requiredDismissals = 3
    private let cooldownSeconds: TimeInterval = 86400 // 1 day

    func trackDismiss() {
        let count = UserDefaults.standard.integer(forKey: dismissCountKey) + 1
        UserDefaults.standard.set(count, forKey: dismissCountKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDismissKey)
    }

    func checkWinback() {
        guard !StoreManager.shared.isPremium else { return }
        let count = UserDefaults.standard.integer(forKey: dismissCountKey)
        let lastDismiss = UserDefaults.standard.double(forKey: lastDismissKey)
        let elapsed = Date().timeIntervalSince1970 - lastDismiss

        if count >= requiredDismissals && elapsed >= cooldownSeconds {
            showWinback = true
            UserDefaults.standard.set(0, forKey: dismissCountKey)
        }
    }
}
SWIFT
echo "   ✅ Created $COORDINATOR_FILE"
fi

# ============================================================================
# Step 5: Inject PaywallKit init into App.swift
# ============================================================================
echo ""
echo "⚙️  Step 5: Updating App.swift with PaywallKit init..."

if grep -q "StoreManager.shared.configure" "$APP_SWIFT" 2>/dev/null; then
  echo "   ⚠️  StoreManager.shared.configure already present, skipping"
elif grep -q "import PaywallKit" "$APP_SWIFT" 2>/dev/null; then
  echo "   ⚠️  PaywallKit already imported, skipping"
else
  echo "   ℹ️  Add these lines to $APP_SWIFT init():"
  echo ""
  echo "   import PaywallKit"
  echo ""
  echo "   // In init():"
  echo "   StoreManager.shared.configure(productIds: [$SWIFT_IDS])"
  echo ""
  echo "   // In body, on .onOpenURL:"
  echo "   PromoCodeManager.shared.handleURL(url)"
  echo ""
  echo "   // In body, on .onAppear:"
  echo "   Task { await PromoCodeManager.shared.checkClipboard() }"
  echo ""
  echo "   // In .onChange(of: scenePhase) where .active:"
  echo "   PaywallCoordinator.shared.checkWinback()"
fi

echo ""
echo "✅ Migration template created for $APP_NAME"
echo ""
echo "Remaining manual steps:"
echo "  1. Add PaywallKit SPM package in Xcode"
echo "  2. Add 'import PaywallKit' to App.swift"
echo "  3. Add StoreManager.shared.configure() to init()"
echo "  4. Replace existing PaywallView references with RemotePaywallView"
echo "  5. Add PromoCodeManager + PaywallCoordinator to App.swift"
echo "  6. Replace isPremium checks: storeKitManager.isPremium → StoreManager.shared.isPremium"
echo "  7. Build and test"
