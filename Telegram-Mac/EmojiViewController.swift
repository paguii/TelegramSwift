//
//  EmojiViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac



var segmentNames:(Int)->String = { value in
    var list:[String] = []
    list.append(tr(.emojiRecent))
    list.append(tr(.emojiSmilesAndPeople))
    list.append(tr(.emojiAnimalsAndNature))
    list.append(tr(.emojiFoodAndDrink))
    list.append(tr(.emojiActivityAndSport))
    list.append(tr(.emojiTravelAndPlaces))
    list.append(tr(.emojiObjects))
    list.append(tr(.emojiSymbols))
    list.append(tr(.emojiFlags))
    return list[value]
}

enum EmojiSegment : Int64, Comparable  {
    case Recent = 0
    case People = 1
    case AnimalsAndNature = 2
    case FoodAndDrink = 3
    case ActivityAndSport = 4
    case TravelAndPlaces = 5
    case Objects = 6
    case Symbols = 7
    case Flags = 8
    
    
    var hashValue:Int {
        return Int(self.rawValue)
    }
}

func ==(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

func <(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

private let emoji:[EmojiSegment:[String]] = {
    assertNotOnMainThread()
    var local:[EmojiSegment:[String]] = [EmojiSegment:[String]]()
    
    let resource:URL?
    if #available(OSX 10.12, *) {
        resource = Bundle.main.url(forResource:"emoji", withExtension:"txt")
    } else {
        resource = Bundle.main.url(forResource:"emoji11", withExtension:"txt")
    }
    if let resource = resource {
        
        var file:String = ""
        
        do {
            file = try String(contentsOf: resource)
            
        } catch {
            print("emoji file not loaded")
        }
        
        let segments = file.components(separatedBy: "\n\n")
        
        for segment in segments {
            
            let list = segment.components(separatedBy: " ")
            
            if let value = EmojiSegment(rawValue: Int64(local.count + 1)) {
                local[value] = list
            }
            
        }
        
    }
    
    return local
    
}()

private func segments(_ emoji: [EmojiSegment : [String]], skinModifiers: [String]) -> [EmojiSegment:[[NSAttributedString]]] {
    var segments:[EmojiSegment:[[NSAttributedString]]] = [:]
    for (key,list) in emoji {
        
        var line:[NSAttributedString] = []
        var lines:[[NSAttributedString]] = []
        var i = 0
        
        for emoji in list {
            
            var e:String = emoji
            for modifier in skinModifiers {
                if emoji.emojiUnmodified == modifier.emojiUnmodified {
                    e = modifier
                }
            }
            
            line.append(.initialize(string: e, font: NSFont.normal(.custom(26))))
            
            i += 1
            if i == 8 {
                
                lines.append(line)
                line.removeAll()
                i = 0
            }
        }
        if line.count > 0 {
            lines.append(line)
        }
        if lines.count > 0 {
            segments[key] = lines
        }
        
    }
    return segments
}


fileprivate var isReady:Bool = false


class EmojiControllerView : View {
    fileprivate let tableView:TableView = TableView(frame:NSZeroRect)
    fileprivate let tabs:HorizontalTableView = HorizontalTableView(frame:NSZeroRect)
    private let borderView:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(tabs)
        addSubview(borderView)

    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.backgroundColor = theme.colors.background
        self.borderView.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 3.0, bounds.width , frame.height - 3.0 - 50)
        tabs.frame = NSMakeRect(0, tableView.frame.maxY + 1, frame.width,49)
        borderView.frame = NSMakeRect(0, frame.height - 50, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EmojiViewController: TelegramGenericViewController<EmojiControllerView>, TableViewDelegate {
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private var disposable:MetaDisposable = MetaDisposable()
 
    private var interactions:EntertainmentInteractions?
    
    override init(_ account: Account) {
        super.init(account)
        _frameRect = NSMakeRect(0, 0, 350, 300)
        self.bar = .init(height: 0)
    }
    
    
    override func loadView() {
        super.loadView()
        genericView.tabs.delegate = self
        updateLocalizationAndTheme()
    }
    
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func selectionWillChange(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
    }
    
    func loadResource() -> Signal <Void,Void> {
        return Signal { (subscriber) -> Disposable in
                _ = emoji
                subscriber.putNext(Void())
                subscriber.putCompletion()
            return ActionDisposable(action: {
                
            });
        } |> runOn(resourcesQueue)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.genericView.tableView.performScrollEvent()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // DO NOT WRITE CODE OUTSIZE READY BLOCK
      
        let ready:(RecentUsedEmoji)->Void = { [weak self] recent in
            if let strongSelf = self {
                strongSelf.readyForDisplay(recent)
                strongSelf.readyOnce()

            }
            
        }
        
        let s:Signal = combineLatest(loadResource(), recentUsedEmoji(postbox: account.postbox), appearanceSignal) |> deliverOnMainQueue
        
        disposable.set(s.start(next: { (_, recent, _) in
            isReady = true
            ready(recent)
        }))
    }
    
    func readyForDisplay(_ recent: RecentUsedEmoji) -> Void {
        
       
        genericView.tableView.removeAll()
        genericView.tabs.removeAll()
        var e = emoji
        e[EmojiSegment.Recent] = recent.emojies
        let seg = segments(e, skinModifiers: recent.skinModifiers)
        let seglist = seg.map { (key,_) -> EmojiSegment in
            return key
        }.sorted(by: <)
        
        let w = floorToScreenPixels(frame.width / CGFloat(seg.count))
        
        genericView.tabs.setFrameSize(NSMakeSize(w * CGFloat(seg.count), genericView.tabs.frame.height))
        genericView.tabs.centerX()
        let initialSize = atomicSize
        var tabIcons:[CGImage] = []
        tabIcons.append(theme.icons.emojiRecentTab)
        tabIcons.append(theme.icons.emojiSmileTab)
        tabIcons.append(theme.icons.emojiNatureTab)
        tabIcons.append(theme.icons.emojiFoodTab)
        tabIcons.append(theme.icons.emojiSportTab)
        tabIcons.append(theme.icons.emojiCarTab)
        tabIcons.append(theme.icons.emojiObjectsTab)
        tabIcons.append(theme.icons.emojiSymbolsTab)
        tabIcons.append(theme.icons.emojiFlagsTab)
        
        var tabIconsSelected:[CGImage] = []
        tabIconsSelected.append(theme.icons.emojiRecentTabActive)
        tabIconsSelected.append(theme.icons.emojiSmileTabActive)
        tabIconsSelected.append(theme.icons.emojiNatureTabActive)
        tabIconsSelected.append(theme.icons.emojiFoodTabActive)
        tabIconsSelected.append(theme.icons.emojiSportTabActive)
        tabIconsSelected.append(theme.icons.emojiCarTabActive)
        tabIconsSelected.append(theme.icons.emojiObjectsTabActive)
        tabIconsSelected.append(theme.icons.emojiSymbolsTabActive)
        tabIconsSelected.append(theme.icons.emojiFlagsTabActive)
        for key in seglist {
            if key != .Recent {
                let _ = genericView.tableView.addItem(item: EStickItem(initialSize.modify({$0}), segment:key, segmentName:segmentNames(key.hashValue)))
            }
            let _ = genericView.tableView.addItem(item: EBlockItem(initialSize.modify({$0}), attrLines: seg[key]!, segment: key, account: account, selectHandler: { [weak self] emoji in
                if let interactions = self?.interactions {
                    interactions.sendEmoji(emoji)
                }
            } ))
            let _ = genericView.tabs.addItem(item: ETabRowItem(initialSize.modify({$0}), icon: tabIcons[key.hashValue], iconSelected:tabIconsSelected[key.hashValue], stableId:key.rawValue, width:w, clickHandler:{[weak self] (stableId) in
                self?.scrollTo(stableId: stableId)
            }))
        }
        //set(stickClass: TableStickItem.self, handler:(Table))
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
            if let view = self?.genericView {
                view.tableView.enumerateVisibleItems(with: { item -> Bool in
                    if let item = item as? EStickItem {
                        view.tabs.changeSelection(stableId: AnyHashable(Int64(item.segment.rawValue)))
                    } else if let item = item as? EBlockItem {
                        view.tabs.changeSelection(stableId: AnyHashable(Int64(item.segment.rawValue)))
                    }
                    return false
                })
            }
        }))
    }
    
    func update(with interactions: EntertainmentInteractions) {
        self.interactions = interactions
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func scrollTo(stableId:AnyHashable) -> Void {
        genericView.tabs.changeSelection(stableId: stableId)
        genericView.tableView.scroll(to: .top(id: stableId, animated: true, focus: false, inset: 0), inset:NSEdgeInsets(top:3))
    }
    

}
