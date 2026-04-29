#!/bin/bash
# Batch PaywallKit Migration
# Processes all apps that need PaywallKit or feature upgrades
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GH="/Users/sushanthtiruvaipati/Documents/GitHub"

echo "============================================"
echo "  PaywallKit Unified Migration"
echo "============================================"
echo ""

# ── PHASE 1: Custom paywall apps → Full PaywallKit ──
echo "═══ PHASE 1: Migrate custom paywall apps to PaywallKit ═══"
echo ""

declare -A CUSTOM_APPS
CUSTOM_APPS=(
  ["fitpulse"]="FitPulse|fitpulse|com.appfactory.fitpulse.premium.monthly,com.appfactory.fitpulse.premium.yearly,com.appfactory.fitpulse.premium.lifetime"
  ["dialdeck"]="DialDeck|dialdeck|com.appfactory.dialdeck.subscription.monthly,com.appfactory.dialdeck.subscription.yearly,com.appfactory.dialdeck.subscription.lifetime"
  ["hormosync"]="HormoSync|hormosync|com.appfactory.hormosync.subscription.monthly,com.appfactory.hormosync.subscription.yearly,com.appfactory.hormosync.premium.lifetime"
  ["fiscalpulse"]="FiscalPulse|fiscalpulse|com.appfactory.fiscalpulse.subscription.monthly,com.appfactory.fiscalpulse.subscription.yearly,com.appfactory.fiscalpulse.lifetime"
  ["vitaltrace-health"]="VitalTrace|vitaltrace|com.appfactory.vitaltrace.subscription.monthly,com.appfactory.vitaltrace.subscription.yearly,com.appfactory.vitaltrace.subscription.lifetime"
  ["pixelpalette-kids"]="PixelPaletteKids|pixelpalettekids|com.appfactory.pixelpalettekids.subscription.monthly,com.appfactory.pixelpalettekids.subscription.yearly,com.appfactory.pixelpalettekids.subscription.lifetime"
  ["qrai-pro"]="QRAIPro|qraipro|com.appfactory.qraipro.premium.monthly,com.appfactory.qraipro.premium.yearly,com.appfactory.qraipro.premium.lifetime"
  ["swiftfax-sign-send"]="SwiftFax|swiftfax|com.appfactory.swiftfaxsignsend.subscription.monthly,com.appfactory.swiftfaxsignsend.subscription.yearly,com.appfactory.swiftfaxsignsend.subscription.lifetime"
  ["claimvault--money-you-re-owed"]="ClaimVault|claimvault|com.appfactory.claimvault.premium.monthly,com.appfactory.claimvault.premium.yearly"
  ["glpcoach--injection---weight-log"]="GLPCoach|glpcoach|com.appfactory.glpcoach.premium.monthly,com.appfactory.glpcoach.premium.yearly"
  ["moodspark-journal"]="MoodSpark|moodspark|com.appfactory.moodspark.premium.monthly,com.appfactory.moodspark.premium.yearly"
  ["routine-revolution"]="RoutineRevolution|routinerevolution|com.appfactory.routinerevolution.premium.monthly,com.appfactory.routinerevolution.premium.yearly"
  ["serenity-coach"]="SerenityCoach|serenitycoach|com.appfactory.serenitycoach.premium.monthly,com.appfactory.serenitycoach.premium.yearly"
  ["mathmaster-cards"]="MathMasterCards|mathmastercards|com.appfactory.mathmastercards.premium.monthly,com.appfactory.mathmastercards.premium.yearly"
  ["fastingpulse"]="FastingPulse|fastingpulse|com.appfactory.fastingpulse.premium.monthly,com.appfactory.fastingpulse.premium.yearly"
  ["fincalc-pro"]="FinCalcPro|fincalcpro|com.appfactory.fincalcpro.premium.monthly,com.appfactory.fincalcpro.premium.yearly"
)

MIGRATED=0
SKIPPED=0
for dir in "${!CUSTOM_APPS[@]}"; do
  IFS='|' read -r name appid products <<< "${CUSTOM_APPS[$dir]}"
  PROJECT="$GH/$dir"
  if [ ! -d "$PROJECT" ]; then
    echo "⏭  $name - directory not found, skipping"
    ((SKIPPED++))
    continue
  fi
  echo "🔧 $name ($appid)..."
  "$SCRIPT_DIR/migrate-app.sh" "$PROJECT" "$name" "$appid" "$products" 2>&1 | grep -E '✅|⚠️|❌|ℹ️' | sed 's/^/   /'
  ((MIGRATED++))
done

echo ""
echo "Phase 1 complete: $MIGRATED migrated, $SKIPPED skipped"

# ── PHASE 2: Add PromoCodeManager to existing PaywallKit apps ──
echo ""
echo "═══ PHASE 2: Add PromoCodeManager to existing PaywallKit apps ═══"
echo ""

PROMO_ADDED=0
PROMO_EXISTING=0

# Apps that already have PromoCodeManager
PROMO_APPS="ScribeAI MeetingMind Audexa ClearVoiceRecorder ReadAloudAI"

find "$GH" -maxdepth 4 -name "*App.swift" -not -path "*/Pods/*" -not -path "*/.build/*" 2>/dev/null | while read appfile; do
  dir=$(dirname "$appfile")
  # Check if this app has PaywallKit
  if grep -q "import PaywallKit" "$appfile" 2>/dev/null; then
    appname=$(basename "$appfile" | sed 's/App.swift//')
    # Check if PromoCodeManager is already set up
    if grep -q "PromoCodeManager" "$appfile" 2>/dev/null; then
      echo "✅ $appname - PromoCodeManager already integrated"
    else
      echo "➕ $appname - needs PromoCodeManager"
      # Check if there's an onOpenURL handler we can add to
      if grep -q "onOpenURL" "$appfile" 2>/dev/null; then
        echo "   ℹ️  Has onOpenURL - add PromoCodeManager.shared.handleURL(url)"
      fi
    fi
  fi
done

echo ""
echo "Phase 2 audit complete"

# ── PHASE 3: Add WinbackOfferView to existing PaywallKit apps ──
echo ""
echo "═══ PHASE 3: Add WinbackOfferView/PaywallCoordinator ═══"
echo ""

find "$GH" -maxdepth 4 -name "PaywallCoordinator.swift" 2>/dev/null | while read f; do
  echo "✅ $(dirname "$f" | xargs basename) has PaywallCoordinator"
done

echo ""
echo "============================================"
echo "  Migration Summary"
echo "============================================"
echo "Run this script to see which apps need work."
echo "For each app, review the ℹ️ items and apply manually."
echo ""
echo "After migration, run the offer code generation:"
echo "  cd $GH/ad-optimizer"
echo "  npx tsx scripts/create-offer-codes.ts"
echo ""
echo "Then create promo campaigns:"
echo "  npx tsx scripts/bulk-stock-codes.ts"
