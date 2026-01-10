# System-Wide Simple Mode Architecture

## Design Philosophy

**Goal**: Make the entire app usable by people with IQ 60 while maintaining full functionality for power users.

**Core Principles**:
1. **Mega Buttons**: 1/3 screen height, impossible to miss
2. **Multi-Sensory**: Visual + Audio + Haptic feedback
3. **Zero Cognitive Load**: One action per screen
4. **Immediate Feedback**: Instant confirmation
5. **No Hidden Features**: Everything visible

## Navigation Architecture

### Two-Tier System

**Tier 1: Ultra-Simple (Main Navigation)**
- Home page with 3 mega buttons (花钱/收钱/查看)
- Each button leads to focused task flow
- No complex menus or tabs

**Tier 2: Responsive (Detail Pages)**
- Transaction lists, settings, etc.
- Use responsive widgets (1.5x scaling)
- Simplified layouts with larger touch targets

## Feature Mapping

### Current Features → Simple Mode Design

| Feature | Normal Mode | Simple Mode Approach |
|---------|-------------|---------------------|
| Home | Dashboard with multiple widgets | 3 mega buttons (done) |
| Add Transaction | Multi-step form | Number pad → Confirm |
| View Transactions | Filterable list | Today's list only |
| Budget | Complex charts | Simple progress bars |
| Statistics | Multiple charts | Single summary card |
| Settings | Long list | 5 mega buttons max |
| Voice Assistant | Chat interface | Already simple |

## Implementation Strategy

### Phase 1: Core Navigation (Current)
- ✅ Ultra-simple home page
- ✅ Mode switching system
- ✅ Responsive widgets

### Phase 2: Main Flows
- Simple transaction view page
- Simple settings page
- Simple budget view page

### Phase 3: Integration
- Update main app router to check mode
- Show ultra-simple versions when in simple mode
- Ensure seamless mode switching

## Key Components

### 1. Simple Mode Router
```dart
Widget _buildPageForMode(UIMode mode, String route) {
  if (mode == UIMode.simple) {
    return _getSimplePage(route);
  }
  return _getNormalPage(route);
}
```

### 2. Simple Page Registry
```dart
final simplePages = {
  '/': UltraSimpleHomePage(),
  '/transactions': UltraSimpleViewPage(),
  '/settings': UltraSimpleSettingsPage(),
  '/budget': UltraSimpleBudgetPage(),
};
```

### 3. Mode-Aware Navigation
```dart
void navigateTo(String route) {
  final mode = ref.read(uiModeProvider).mode;
  final page = mode == UIMode.simple
    ? simplePages[route]
    : normalPages[route];
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
```

## Design Patterns for Simple Pages

### Pattern 1: Mega Button Grid
- 2-5 buttons max per screen
- Each button 1/3 to 1/5 screen height
- Color-coded by function
- Icon + Text label

### Pattern 2: Single Focus
- One task per screen
- No tabs or complex navigation
- Back button always visible (80pt)

### Pattern 3: Immediate Feedback
- Success: Green checkmark + sound + haptic
- Error: Red X + sound + haptic
- Processing: Large spinner + sound

### Pattern 4: Voice Integration
- Every screen has voice button (80pt)
- Voice can complete any action
- Audio feedback for all actions

## Accessibility Scores Target

| Feature | Normal Mode | Simple Mode | Target |
|---------|-------------|-------------|--------|
| Navigation | 5/10 | 10/10 | ✓ |
| Add Transaction | 4/10 | 10/10 | ✓ |
| View Data | 3/10 | 9/10 | ✓ |
| Budget | 3/10 | 9/10 | ✓ |
| Settings | 4/10 | 10/10 | ✓ |
| Voice | 6/10 | 10/10 | ✓ |

## Technical Implementation

### File Structure
```
lib/
  pages/
    ultra_simple/
      ultra_simple_home_page.dart (done)
      ultra_simple_view_page.dart (done)
      ultra_simple_settings_page.dart (new)
      ultra_simple_budget_page.dart (new)
  providers/
    ui_mode_provider.dart (done)
    simple_mode_router_provider.dart (new)
  widgets/
    responsive_widgets.dart (done)
    mode_switch_widgets.dart (done)
    simple_mode_scaffold.dart (new)
```

### Simple Mode Scaffold
Reusable wrapper for all simple pages:
- Large back button
- Voice button
- Mode switch button
- Consistent styling

## Migration Path

### For Existing Pages
1. Check if page needs ultra-simple version
2. If yes, create in `ultra_simple/` directory
3. If no, make responsive with existing widgets
4. Update router to use mode-aware navigation

### For New Features
1. Design simple version first
2. Ensure it achieves 9-10/10 accessibility
3. Then add advanced features for normal mode

## Success Criteria

- ✓ User with IQ 60 can complete all basic tasks
- ✓ No training required
- ✓ Zero errors possible
- ✓ Seamless mode switching
- ✓ No feature loss in simple mode
- ✓ Performance impact < 5%
