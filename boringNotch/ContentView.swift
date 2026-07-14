//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var pomodoroTimerStore = PomodoroTimerStore.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?
    @State private var gestureProgress: CGFloat = .zero
    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    private var notchWindowHeight: CGFloat {
        vm.notchState == .open ? vm.notchSize.height + shadowPadding : windowSize.height
    }

    private var topCornerRadius: CGFloat {
       ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.top
                : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var showsIdlePomodoroContent: Bool {
        !coordinator.expandingView.show
            && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        } else if showsIdlePomodoroContent
            && Defaults[.pomodoroNotchPresence] == .both
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    private var pomodoroOutlineColor: Color {
        if pomodoroTimerStore.timeRemaining <= 60 { return .red }
        if pomodoroTimerStore.timeRemaining <= 180 { return .orange }
        return .green
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchContentView(
                    albumArtNamespace: albumArtNamespace,
                    isHovering: $isHovering,
                    gestureProgress: $gestureProgress
                )
                .frame(alignment: .top)
                .padding(
                    .horizontal,
                    vm.notchState == .open
                    ? Defaults[.cornerRadiusScaling]
                    ? (cornerRadiusInsets.opened.top) : (cornerRadiusInsets.opened.bottom)
                    : cornerRadiusInsets.closed.bottom
                )
                .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                .background(.black)
                .clipShape(currentNotchShape)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 1)
                        .padding(.horizontal, topCornerRadius)
                }
                .overlay(alignment: .top) {
                    if vm.notchState == .closed
                        && showsIdlePomodoroContent
                        && !coordinator.sneakPeek.show
                        && Defaults[.pomodoroNotchPresence] == .timerOnly
                        && pomodoroTimerStore.isRunning
                    {
                        currentNotchShape
                            .stroke(pomodoroOutlineColor, lineWidth: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .shadow(
                    color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                        ? .black.opacity(0.7) : .clear, radius: Defaults[.cornerRadiusScaling] ? 6 : 4
                )
                .padding(
                    .bottom,
                    vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                )
            
            mainLayout
                .frame(height: vm.notchState == .open ? vm.notchSize.height : nil, alignment: .top)
                .conditionalModifier(true) { view in
                    let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                    let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                    
                    return view
                        .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: vm.notchSize)
                        .animation(.smooth, value: gestureProgress)
                }
                .contentShape(Rectangle())
                .onHover { hovering in
                    handleHover(hovering)
                }
                .onTapGesture {
                    doOpen()
                }
                .conditionalModifier(Defaults[.enableGestures]) { view in
                    view
                        .panGesture(direction: .down) { translation, phase in
                            handleDownGesture(translation: translation, phase: phase)
                        }
                }
                .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                    view
                        .panGesture(direction: .up) { translation, phase in
                            handleUpGesture(translation: translation, phase: phase)
                        }
                }
                .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                    if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                        hoverTask?.cancel()
                        hoverTask = Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                    self.vm.close()
                                }
                            }
                        }
                    }
                }
                .onChange(of: vm.notchState) { _, newState in
                    if newState == .closed && isHovering {
                        withAnimation {
                            isHovering = false
                        }
                    }
                }
                .onChange(of: vm.isBatteryPopoverActive) {
                    if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                        hoverTask?.cancel()
                        hoverTask = Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                    self.vm.close()
                                }
                            }
                        }
                    }
                }
                .sensoryFeedback(.alignment, trigger: haptics)
                .contextMenu {
                    Button("Settings") {
                        DispatchQueue.main.async {
                            SettingsWindowController.shared.showWindow()
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: notchWindowHeight, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: coordinator.currentView) { _, newView in
            hoverTask?.cancel()
            vm.setTransitioning()
            let targetHeight: CGFloat = newView == .productivity ? 380 : openNotchSize.height
            guard vm.openNotchHeight != targetHeight else { return }
            vm.openNotchHeight = targetHeight

            if vm.notchState == .open {
                vm.notchSize = CGSize(width: openNotchSize.width, height: targetHeight)
                if let window = vm.window {
                    let newWindowHeight = targetHeight + shadowPadding
                    let currentFrame = window.frame
                    let newFrame = CGRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y + (currentFrame.height - newWindowHeight),
                        width: currentFrame.width,
                        height: newWindowHeight
                    )
                    window.setFrame(newFrame, display: true, animate: false)
                }
            }
        }
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !self.vm.isCupPickerActive && !SharingStateManager.shared.preventNotchClose {
                    self.vm.close()
                }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
