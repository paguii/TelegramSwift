//
//  PasscodeSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import LocalAuthentication

private enum PasscodeEntry : Comparable, Identifiable {
    case turnOn(sectionId:Int)
    case turnOff(sectionId:Int)
    case turnOnDescription(sectionId:Int)
    case turnOffDescription(sectionId:Int)
    case change(sectionId:Int)
    case autoLock(sectionId:Int, time:Int32?)
    case turnTouchId(sectionId:Int, enabled: Bool)
    case section(sectionId:Int)
    
    var stableId:Int {
        switch self {
        case .turnOn:
            return 0
        case .turnOff:
            return 1
        case .turnOnDescription:
            return 2
        case .turnOffDescription:
            return 3
        case .change:
            return 4
        case .autoLock:
            return 5
        case .turnTouchId:
            return 6
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var stableIndex:Int {
        switch self {
        case let .turnOn(sectionId):
            return (sectionId * 1000) + stableId
        case let .turnOff(sectionId):
            return (sectionId * 1000) + stableId
        case let .turnOnDescription(sectionId):
            return (sectionId * 1000) + stableId
        case let .turnOffDescription(sectionId):
            return (sectionId * 1000) + stableId
        case let .change(sectionId):
            return (sectionId * 1000) + stableId
        case let .autoLock(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .turnTouchId(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
}

private func <(lhs:PasscodeEntry, rhs:PasscodeEntry) -> Bool {
    return lhs.stableIndex < rhs.stableIndex
}

private func ==(lhs:PasscodeEntry, rhs:PasscodeEntry) -> Bool {
    switch lhs {
    case let .turnOn(sectionId):
        if case .turnOn(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .turnOff(sectionId):
        if case .turnOff(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .turnOnDescription(sectionId):
        if case .turnOnDescription(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .turnOffDescription(sectionId):
        if case .turnOffDescription(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .change(sectionId):
        if case .change(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .autoLock(lhsSectionId, lhsTime):
        if case let .autoLock(rhsSectionId, rhsTime) = rhs {
            return lhsSectionId == rhsSectionId && lhsTime == rhsTime
        } else {
            return false
        }
    case let .turnTouchId(lhsSectionId, lhsEnabled):
        if case let .turnTouchId(rhsSectionId, rhsEnabled) = rhs {
            return lhsSectionId == rhsSectionId && lhsEnabled == rhsEnabled
        } else {
            return false
        }
    case let .section(sectionId):
        if case .section(sectionId) = rhs {
            return true
        } else {
            return false
        }
    }
}

private func passcodeSettinsEntry(_ passcode: PostboxAccessChallengeData, _ additional: AdditionalSettings) -> [PasscodeEntry] {
    var entries:[PasscodeEntry] = []
    
    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    switch passcode {
    case .none:
        entries.append(.turnOn(sectionId: sectionId))
        entries.append(.turnOnDescription(sectionId: sectionId))
    case .plaintextPassword, .numericalPassword:
        entries.append(.turnOff(sectionId: sectionId))
        entries.append(.change(sectionId: sectionId))
        entries.append(.turnOffDescription(sectionId: sectionId))
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        entries.append(.autoLock(sectionId: sectionId, time: passcode.timeout))
        
        let context = LAContext()
         if context.canUseBiometric {
            entries.append(.turnTouchId(sectionId: sectionId, enabled: additional.useTouchId))
        }
        
    }
    
    
    return entries
}

private let actionStyle:ControlStyle = blueActionButton

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PasscodeEntry>], right: [AppearanceWrapperEntry<PasscodeEntry>], initialSize:NSSize, arguments:PasscodeSettingsArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: entry.stableId)
        case .turnOn:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.passcodeTurnOn), nameStyle: actionStyle, type: .none, action: { 
                arguments.turnOn()
            })
        case .turnOff:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.passcodeTurnOff), nameStyle: actionStyle, type: .none, action: {
                arguments.turnOff()
            })
        case .change:
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.passcodeChange), nameStyle: actionStyle, type: .none, action: {
                arguments.change()
            })
        case .turnOnDescription, .turnOffDescription:
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: tr(.passcodeTurnOnDescription))
        case .turnTouchId(_, let enabled):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.passcodeUseTouchId), type: .switchable(stateback: {
                return enabled
            }), action: {
                arguments.toggleTouchId(!enabled)
            })
        case let .autoLock(sectionId: _, time: time):
            
            var text:String
            if let time = time {
                if time < 60 {
                    text = tr(.timerSecondsCountable(Int(time)))
                } else if time <= 60 * 60  {
                    text = tr(.timerMinutesCountable(Int(time / 60)))
                } else if time <= 60 * 60 * 24  {
                    text = tr(.timerHoursCountable(Int(time / 60) / 60))
                } else {
                    text = tr(.timerDaysCountable(Int(time / 60) / 60 / 24))
                }
                text = tr(.passcodeAutoLockIfAway(text))
            } else {
                text = tr(.passcodeAutoLockDisabled)
            }
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(.passcodeAutolock), type: .context {
                return text
            }, action: {
                arguments.ifAway()
            })
        }
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


private final class PasscodeSettingsArguments {
    let account:Account
    let turnOn:()->Void
    let turnOff:()->Void
    let change:()->Void
    let ifAway:()->Void
    let toggleTouchId:(Bool)->Void
    init(_ account:Account, turnOn: @escaping()->Void, turnOff: @escaping()->Void, change:@escaping()->Void, ifAway: @escaping()-> Void, toggleTouchId:@escaping(Bool)->Void) {
        self.account = account
        self.turnOn = turnOn
        self.turnOff = turnOff
        self.change = change
        self.ifAway = ifAway
        self.toggleTouchId = toggleTouchId
    }
}

class PasscodeSettingsViewController: TableViewController {
    
    private let actionUpdate:Promise<Bool> = Promise(false)
    
    private func show(with state: PasscodeViewState) {
        let controller = PasscodeLockController(account, state)
        actionUpdate.set(controller.doneValue)
        showModal(with: controller, for: mainWindow)
    }
    
    func updateAwayTimeout(_ timeout:Int32?) {
        self.actionUpdate.set(account.postbox.modify { modifier -> Bool in
            
            switch modifier.getAccessChallengeData() {
            case .none:
                break
            case let .numericalPassword(passcode, _, attempts):
                modifier.setAccessChallengeData(.numericalPassword(value: passcode, timeout: timeout, attempts: attempts))
            case let .plaintextPassword(passcode, _, attempts):
                modifier.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: timeout, attempts: attempts))
            }
            return true
        })
    }
    
    func showIfAwayOptions() {
        if let item = genericView.item(stableId: Int(5)), let view = (genericView.viewNecessary(at: item.index) as? GeneralInteractedRowView)?.textView {
            
            var items:[SPopoverItem] = []
            
            items.append(SPopoverItem(tr(.passcodeAutoLockDisabled), { [weak self] in
                self?.updateAwayTimeout(nil)
            }))
            
            if isDebug {
                //
                items.append(SPopoverItem(tr(.passcodeAutoLockIfAway(tr(.timerSecondsCountable(5)))), { [weak self] in
                    self?.updateAwayTimeout(5)
                }))
            }
            
            
            
            items.append(SPopoverItem(tr(.passcodeAutoLockIfAway(tr(.timerMinutesCountable(1)))), { [weak self] in
                self?.updateAwayTimeout(60)
            }))
            items.append(SPopoverItem(tr(.passcodeAutoLockIfAway(tr(.timerMinutesCountable(5)))), { [weak self] in
                self?.updateAwayTimeout(60 * 5)
            }))
            items.append(SPopoverItem(tr(.passcodeAutoLockIfAway(tr(.timerHoursCountable(1)))), { [weak self] in
                self?.updateAwayTimeout(60 * 60)
            }))
            items.append(SPopoverItem(tr(.passcodeAutoLockIfAway(tr(.timerHoursCountable(5)))), { [weak self] in
                self?.updateAwayTimeout(60 * 60 * 5)
            }))
            
            
            showPopover(for: view, with: SPopoverViewController(items: items), edge: .minX, inset: NSMakePoint(0, -25))
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        let arguments = PasscodeSettingsArguments(account, turnOn: { [weak self] in
            self?.show(with: .enable(.new))
        }, turnOff: { [weak self] in
            self?.show(with: .disable(.old))
        }, change: { [weak self] in
            self?.show(with: .change(.old))
        }, ifAway: { [weak self] in
            self?.showIfAwayOptions()
        }, toggleTouchId: { enabled in
            _ = updateAdditionalSettingsInteractively(postbox: account.postbox, { current -> AdditionalSettings in
                return current.withUpdatedTouchId(enabled)
            }).start()
        })
        
        let initialSize = self.atomicSize.modify({$0})
        
       
        let previous:Atomic<[AppearanceWrapperEntry<PasscodeEntry>]> = Atomic(value: [])
        
        genericView.merge(with: combineLatest(actionUpdate.get() |> mapToSignal { _ in
            return account.postbox.modify { modifier -> PostboxAccessChallengeData in
                return modifier.getAccessChallengeData()
            }
        } |> deliverOn(prepareQueue), appearanceSignal |> deliverOn(prepareQueue), additionalSettings(postbox: account.postbox) |> deliverOnPrepareQueue) |> map { passcode, appearance, additional in
            let entries = passcodeSettinsEntry(passcode, additional).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize, arguments: arguments)
        } |> deliverOnMainQueue)
        
        readyOnce()
    }
    
    
}
