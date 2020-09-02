
//  https://gist.github.com/onevcat/2d1ceff1c657591eebde
//  Timer break retain cycle

import Foundation

extension Timer {
    class func Player_scheduledTimerWithTimeInterval(_ timeInterval: TimeInterval, block: @escaping ()->(), repeats: Bool) -> Timer {
        return self.scheduledTimer(timeInterval: timeInterval, target:
            self, selector: #selector(self.Player_blcokInvoke(_:)), userInfo: block, repeats: repeats)
    }
    
    @objc class func Player_blcokInvoke(_ timer: Timer) {
        let block: ()->() = timer.userInfo as! ()->()
        block()
    }

}
