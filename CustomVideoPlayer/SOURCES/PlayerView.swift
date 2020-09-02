
import UIKit
import MediaPlayer
import SnapKit

public protocol PlayerViewDelegate: class {
    
    /// Fullscreen
    ///
    /// - Parameters:
    ///   - playerView: player view
    ///   - fullscreen: Whether full screen
    func PlayerView(_ playerView: PlayerView, willFullscreen isFullscreen: Bool)
    
    /// Close play view
    ///
    /// - Parameter playerView: player view
    func PlayerView(didTappedClose playerView: PlayerView)
    
    /// Displaye control
    ///
    /// - Parameter playerView: playerView
    func PlayerView(didDisplayControl playerView: PlayerView)
    
}

// MARK: - delegate methods optional
public extension PlayerViewDelegate {
    
    func PlayerView(_ playerView: PlayerView, willFullscreen fullscreen: Bool){}
    
    func PlayerView(didTappedClose playerView: PlayerView) {}
    
    func PlayerView(didDisplayControl playerView: PlayerView) {}
}

public enum PlayerViewPanGestureDirection: Int {
    case vertical
    case horizontal
}


open class PlayerView: UIView {
    
    weak open var Player : Player?
    open var controlViewDuration : TimeInterval = 5.0  /// default 5.0
    open fileprivate(set) var playerLayer : AVPlayerLayer?
    open fileprivate(set) var isFullScreen : Bool = false
    open fileprivate(set) var isTimeSliding : Bool = false
    open fileprivate(set) var isDisplayControl : Bool = true {
        didSet {
            if isDisplayControl != oldValue {
                delegate?.PlayerView(didDisplayControl: self)
            }
        }
    }
    open weak var delegate : PlayerViewDelegate?
    // top view
    open var topView : UIView = {
        let view = UIView()
        view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        return view
    }()
    open var titleLabel : UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont.boldSystemFont(ofSize: 16.0)
        return label
    }()
    open var closeButton : UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()
    
    // bottom view
    open var bottomView : UIView = {
        let view = UIView()
        view.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        return view
    }()
    open var timeSlider = PlayerSlider ()
    open var loadingIndicator = PlayerLoadingIndicator()
    open var fullscreenButton : UIButton = UIButton(type: .custom)
    open var timeLabel : UILabel = UILabel()
    open var playButtion : UIButton = UIButton(type: .custom)
    open var volumeSlider : UISlider!
    open var replayButton : UIButton = UIButton(type: .custom)
    open fileprivate(set) var panGestureDirection : PlayerViewPanGestureDirection = .horizontal
    fileprivate var isVolume : Bool = false
    fileprivate var sliderSeekTimeValue : TimeInterval = .nan
    fileprivate var timer : Timer = {
        let time = Timer()
        return time
    }()
    
    fileprivate weak var parentView : UIView?
    fileprivate var viewFrame = CGRect()
    
    // GestureRecognizer
    open var singleTapGesture = UITapGestureRecognizer()
    open var doubleTapGesture = UITapGestureRecognizer()
    open var panGesture = UIPanGestureRecognizer()
    
    //MARK:- life cycle
    public override init(frame: CGRect) {
        self.playerLayer = AVPlayerLayer(player: nil)
        super.init(frame: frame)
        addDeviceOrientationNotifications()
        addGestureRecognizer()
        configurationVolumeSlider()
        configurationUI()
    }
    
    public convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer.invalidate()
        playerLayer?.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        updateDisplayerView(frame: bounds)
    }
    
    open func setPlayer(Player: Player) {
        self.Player = Player
    }
    
    open func reloadPlayerLayer() {
        playerLayer = AVPlayerLayer(player: self.Player?.player)
        layer.insertSublayer(self.playerLayer!, at: 0)
        updateDisplayerView(frame: self.bounds)
        timeSlider.isUserInteractionEnabled = Player?.mediaFormat != .m3u8
        reloadGravity()
    }
    
    
    /// play state did change
    ///
    /// - Parameter state: state
    open func playStateDidChange(_ state: PlayerState) {
        playButtion.isSelected = state == .playing
        replayButton.isHidden = !(state == .playFinished)
        replayButton.isHidden = !(state == .playFinished)
        if state == .playing || state == .playFinished {
            setupTimer()
        }
        if state == .playFinished {
            loadingIndicator.isHidden = true
        }
    }
    
    /// buffer state change
    ///
    /// - Parameter state: buffer state
    open func bufferStateDidChange(_ state: PlayerBufferstate) {
        if state == .buffering {
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.isHidden = true
            loadingIndicator.stopAnimating()
        }
        
        var current = formatSecondsToString((Player?.currentDuration)!)
        if (Player?.totalDuration.isNaN)! {  // HLS
            current = "00:00"
        }
        if state == .readyToPlay && !isTimeSliding {
            timeLabel.text = "\(current + " / " +  (formatSecondsToString((Player?.totalDuration)!)))"
        }
    }
    
    /// buffer duration
    ///
    /// - Parameters:
    ///   - bufferedDuration: buffer duration
    ///   - totalDuration: total duratiom
    open func bufferedDidChange(_ bufferedDuration: TimeInterval, totalDuration: TimeInterval) {
        timeSlider.setProgress(Float(bufferedDuration / totalDuration), animated: true)
    }
    
    /// player diration
    ///
    /// - Parameters:
    ///   - currentDuration: current duration
    ///   - totalDuration: total duration
    open func playerDurationDidChange(_ currentDuration: TimeInterval, totalDuration: TimeInterval) {
        var current = formatSecondsToString(currentDuration)
        if totalDuration.isNaN {  // HLS
            current = "00:00"
        }
        if !isTimeSliding {
            timeLabel.text = "\(current + " / " +  (formatSecondsToString(totalDuration)))"
            timeSlider.value = Float(currentDuration / totalDuration)
        }
    }
    
    open func configurationUI() {
        backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        configurationTopView()
        configurationBottomView()
        configurationReplayButton()
        setupViewAutoLayout()
    }
    
    open func reloadPlayerView() {
        playerLayer = AVPlayerLayer(player: nil)
        timeSlider.value = Float(0)
        timeSlider.setProgress(0, animated: false)
        replayButton.isHidden = true
        isTimeSliding = false
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
        timeLabel.text = "--:-- / --:--"
        reloadPlayerLayer()
    }
    
    /// control view display
    ///
    /// - Parameter display: is display
    open func displayControlView(_ isDisplay:Bool) {
        if isDisplay {
            displayControlAnimation()
        } else {
            hiddenControlAnimation()
        }
    }
}

// MARK: - public
extension PlayerView {
    
    open func updateDisplayerView(frame: CGRect) {
        playerLayer?.frame = frame
    }
    
    open func reloadGravity() {
        if Player != nil {
            switch Player!.gravityMode {
            case .resize:
                playerLayer?.videoGravity = .resize
            case .resizeAspect:
                playerLayer?.videoGravity = .resizeAspect
            case .resizeAspectFill:
                playerLayer?.videoGravity = .resizeAspectFill
            }
        }
    }

    open func enterFullscreen() {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            parentView = (self.superview)!
            viewFrame = self.frame
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .landscapeRight
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
    }
    
    open func exitFullscreen() {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIApplication.shared.statusBarOrientation = .portrait
    }
    
    /// play failed
    ///
    /// - Parameter error: error
    open func playFailed(_ error: PlayerError) {
        // error
    }
    
    public func formatSecondsToString(_ seconds: TimeInterval) -> String {
        if seconds.isNaN{
            return "00:00"
        }
        let interval = Int(seconds)
        let sec = Int(seconds.truncatingRemainder(dividingBy: 60))
        let min = interval / 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - private
extension PlayerView {
    
    internal func play() {
        playButtion.isSelected = true
    }
    
    internal func pause() {
        playButtion.isSelected = false
    }
    
    internal func displayControlAnimation() {
        bottomView.isHidden = false
        topView.isHidden = false
        isDisplayControl = true
        UIView.animate(withDuration: 0.5, animations: {
            self.bottomView.alpha = 1
            self.topView.alpha = 1
        }) { (completion) in
            self.setupTimer()
        }
    }
    internal func hiddenControlAnimation() {
        timer.invalidate()
        isDisplayControl = false
        UIView.animate(withDuration: 0.5, animations: {
            self.bottomView.alpha = 0
            self.topView.alpha = 0
        }) { (completion) in
            self.bottomView.isHidden = true
            self.topView.isHidden = true
        }
    }
    internal func setupTimer() {
        timer.invalidate()
        timer = Timer.Player_scheduledTimerWithTimeInterval(self.controlViewDuration, block: {  [weak self]  in
            guard let strongSelf = self else { return }
            strongSelf.displayControlView(false)
        }, repeats: false)
    }
    internal func addDeviceOrientationNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationWillChange(_:)), name: UIApplication.willChangeStatusBarOrientationNotification, object: nil)
    }
    
    internal func configurationVolumeSlider() {
        let volumeView = MPVolumeView()
        if let view = volumeView.subviews.first as? UISlider {
            volumeSlider = view
        }
    }
}


// MARK: - GestureRecognizer
extension PlayerView {
    
    internal func addGestureRecognizer() {
        singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onSingleTapGesture(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        singleTapGesture.delegate = self
        addGestureRecognizer(singleTapGesture)
        
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        doubleTapGesture.delegate = self
        addGestureRecognizer(doubleTapGesture)
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPanGesture(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        singleTapGesture.require(toFail: doubleTapGesture)
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension PlayerView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view as? PlayerView != nil) {
            return true
        }
        return false
    }
}

// MARK: - Event
extension PlayerView {
    
    @objc internal func timeSliderValueChanged(_ sender: PlayerSlider) {
        isTimeSliding = true
        if let duration = Player?.totalDuration {
            let currentTime = Double(sender.value) * duration
            timeLabel.text = "\(formatSecondsToString(currentTime) + " / " +  (formatSecondsToString(duration)))"
        }
    }
    
    @objc internal func timeSliderTouchDown(_ sender: PlayerSlider) {
        isTimeSliding = true
        timer.invalidate()
    }
    
    @objc internal func timeSliderTouchUpInside(_ sender: PlayerSlider) {
        isTimeSliding = true
        
        if let duration = Player?.totalDuration {
            let currentTime = Double(sender.value) * duration
            Player?.seekTime(currentTime, completion: { [weak self] (finished) in
                guard let strongSelf = self else { return }
                if finished {
                    strongSelf.isTimeSliding = false
                    strongSelf.setupTimer()
                }
            })
            timeLabel.text = "\(formatSecondsToString(currentTime) + " / " +  (formatSecondsToString(duration)))"
        }
    }
    
    @objc internal func onPlayerButton(_ sender: UIButton) {
        if !sender.isSelected {
            Player?.play()
        } else {
            Player?.pause()
        }
    }
    
    @objc internal func onFullscreen(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        isFullScreen = sender.isSelected
        if isFullScreen {
            enterFullscreen()
        } else {
            exitFullscreen()
        }
    }
    
    
    /// Single Tap Event
    ///
    /// - Parameter gesture: Single Tap Gesture
    @objc open func onSingleTapGesture(_ gesture: UITapGestureRecognizer) {
        isDisplayControl = !isDisplayControl
        displayControlView(isDisplayControl)
    }
    
    /// Double Tap Event
    ///
    /// - Parameter gesture: Double Tap Gesture
    @objc open func onDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        
        guard Player == nil else {
            switch Player!.state {
            case .playFinished:
                break
            case .playing:
                Player?.pause()
            case .paused:
                Player?.play()
            case .none:
                break
            case .error:
                break
            }
            return
        }
    }
    
    /// Pan Event
    ///
    /// - Parameter gesture: Pan Gesture
    @objc open func onPanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let location = gesture.location(in: self)
        let velocity = gesture.velocity(in: self)
        switch gesture.state {
        case .began:
            let x = abs(translation.x)
            let y = abs(translation.y)
            if x < y {
                panGestureDirection = .vertical
                if location.x > bounds.width / 2 {
                    isVolume = true
                } else {
                    isVolume = false
                }
            } else if x > y{
                guard Player?.mediaFormat == .m3u8 else {
                    panGestureDirection = .horizontal
                    return
                }
            }
        case .changed:
            switch panGestureDirection {
            case .horizontal:
                if Player?.currentDuration == 0 { break }
                sliderSeekTimeValue = panGestureHorizontal(velocity.x)
            case .vertical:
                panGestureVertical(velocity.y)
            }
        case .ended:
            switch panGestureDirection{
            case .horizontal:
                if sliderSeekTimeValue.isNaN { return }
                self.Player?.seekTime(sliderSeekTimeValue, completion: { [weak self] (finished) in
                    guard let strongSelf = self else { return }
                    if finished {
                        
                        strongSelf.isTimeSliding = false
                        strongSelf.setupTimer()
                    }
                })
            case .vertical:
                isVolume = false
            }
            
        default:
            break
        }
    }
    
    internal func panGestureHorizontal(_ velocityX: CGFloat) -> TimeInterval {
        displayControlView(true)
        isTimeSliding = true
        timer.invalidate()
        let value = timeSlider.value
        if let _ = Player?.currentDuration ,let totalDuration = Player?.totalDuration {
            let sliderValue = (TimeInterval(value) *  totalDuration) + TimeInterval(velocityX) / 100.0 * (TimeInterval(totalDuration) / 400)
            timeSlider.setValue(Float(sliderValue/totalDuration), animated: true)
            return sliderValue
        } else {
            return TimeInterval.nan
        }
        
    }
    
    internal func panGestureVertical(_ velocityY: CGFloat) {
        isVolume ? (volumeSlider.value -= Float(velocityY / 10000)) : (UIScreen.main.brightness -= velocityY / 10000)
    }

    @objc internal func onCloseView(_ sender: UIButton) {
        delegate?.PlayerView(didTappedClose: self)
    }
    
    @objc internal func onReplay(_ sender: UIButton) {
        Player?.replaceVideo((Player?.contentURL)!)
        Player?.play()
    }
    
    @objc internal func deviceOrientationWillChange(_ sender: Notification) {
        let orientation = UIDevice.current.orientation
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if statusBarOrientation == .portrait{
            if superview != nil {
                parentView = (superview)!
                viewFrame = frame
            }
        }
        switch orientation {
        case .unknown:
            break
        case .faceDown:
            break
        case .faceUp:
            break
        case .landscapeLeft:
            onDeviceOrientation(true, orientation: .landscapeLeft)
        case .landscapeRight:
            onDeviceOrientation(true, orientation: .landscapeRight)
        case .portrait:
            onDeviceOrientation(false, orientation: .portrait)
        case .portraitUpsideDown:
            onDeviceOrientation(false, orientation: .portraitUpsideDown)
        }
    }
    internal func onDeviceOrientation(_ fullScreen: Bool, orientation: UIInterfaceOrientation) {
        let statusBarOrientation = UIApplication.shared.statusBarOrientation
        if orientation == statusBarOrientation {
            if orientation == .landscapeLeft || orientation == .landscapeLeft {
                let rectInWindow = convert(bounds, to: UIApplication.shared.keyWindow)
                removeFromSuperview()
                frame = rectInWindow
                UIApplication.shared.keyWindow?.addSubview(self)
                self.snp.remakeConstraints({ [weak self] (make) in
                    guard let strongSelf = self else { return }
                    make.width.equalTo(strongSelf.superview!.bounds.width)
                    make.height.equalTo(strongSelf.superview!.bounds.height)
                })
            }
        } else {
            if orientation == .landscapeLeft || orientation == .landscapeRight {
                let rectInWindow = convert(bounds, to: UIApplication.shared.keyWindow)
                removeFromSuperview()
                frame = rectInWindow
                UIApplication.shared.keyWindow?.addSubview(self)
                self.snp.remakeConstraints({ [weak self] (make) in
                    guard let strongSelf = self else { return }
                    make.width.equalTo(strongSelf.superview!.bounds.height)
                    make.height.equalTo(strongSelf.superview!.bounds.width)
                })
            } else if orientation == .portrait{
                if parentView == nil { return }
                removeFromSuperview()
                parentView!.addSubview(self)
                let frame = parentView!.convert(viewFrame, to: UIApplication.shared.keyWindow)
                self.snp.remakeConstraints({ (make) in
                    make.centerX.equalTo(viewFrame.midX)
                    make.centerY.equalTo(viewFrame.midY)
                    make.width.equalTo(frame.width)
                    make.height.equalTo(frame.height)
                })
                viewFrame = CGRect()
                parentView = nil
            }
        }
        isFullScreen = fullScreen
        fullscreenButton.isSelected = fullScreen
        delegate?.PlayerView(self, willFullscreen: isFullScreen)
    }
}

//MARK: - UI autoLayout
extension PlayerView {

    internal func configurationReplayButton() {
        addSubview(self.replayButton)
        let replayImage = PlayerUtils.imageResource("Player_ic_replay")
        replayButton.setImage(PlayerUtils.imageSize(image: replayImage!, scaledToSize: CGSize(width: 30, height: 30)), for: .normal)
        replayButton.addTarget(self, action: #selector(onReplay(_:)), for: .touchUpInside)
        replayButton.isHidden = true
    }
    
    internal func configurationTopView() {
        addSubview(topView)
        titleLabel.text = "this is a title."
        topView.addSubview(titleLabel)
        let closeImage = PlayerUtils.imageResource("Player_ic_nav_back")
        closeButton.setImage(PlayerUtils.imageSize(image: closeImage!, scaledToSize: CGSize(width: 15, height: 20)), for: .normal)
        closeButton.addTarget(self, action: #selector(onCloseView(_:)), for: .touchUpInside)
        topView.addSubview(closeButton)
    }
    
    internal func configurationBottomView() {
        addSubview(bottomView)
        timeSlider.addTarget(self, action: #selector(timeSliderValueChanged(_:)),
                             for: .valueChanged)
        timeSlider.addTarget(self, action: #selector(timeSliderTouchUpInside(_:)), for: .touchUpInside)
        timeSlider.addTarget(self, action: #selector(timeSliderTouchDown(_:)), for: .touchDown)
        loadingIndicator.lineWidth = 1.0
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
        addSubview(loadingIndicator)
        bottomView.addSubview(timeSlider)
        
        let playImage = PlayerUtils.imageResource("Player_ic_play")
        let pauseImage = PlayerUtils.imageResource("Player_ic_pause")
        playButtion.setImage(PlayerUtils.imageSize(image: playImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .normal)
        playButtion.setImage(PlayerUtils.imageSize(image: pauseImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .selected)
        playButtion.addTarget(self, action: #selector(onPlayerButton(_:)), for: .touchUpInside)
        bottomView.addSubview(playButtion)
        
        timeLabel.textAlignment = .center
        timeLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        timeLabel.font = UIFont.systemFont(ofSize: 12.0)
        timeLabel.text = "--:-- / --:--"
        bottomView.addSubview(timeLabel)
        
        let enlargeImage = PlayerUtils.imageResource("Player_ic_fullscreen")
        let narrowImage = PlayerUtils.imageResource("Player_ic_fullscreen_exit")
        fullscreenButton.setImage(PlayerUtils.imageSize(image: enlargeImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .normal)
        fullscreenButton.setImage(PlayerUtils.imageSize(image: narrowImage!, scaledToSize: CGSize(width: 15, height: 15)), for: .selected)
        fullscreenButton.addTarget(self, action: #selector(onFullscreen(_:)), for: .touchUpInside)
        bottomView.addSubview(fullscreenButton)
        
    }
    
    internal func setupViewAutoLayout() {
        replayButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.center.equalTo(strongSelf)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        // top view layout
        topView.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf)
            make.right.equalTo(strongSelf)
            make.top.equalTo(strongSelf)
            make.height.equalTo(64)
        }
        closeButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.topView).offset(10)
            make.top.equalTo(strongSelf.topView).offset(28)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
        titleLabel.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.closeButton.snp.right).offset(20)
            make.centerY.equalTo(strongSelf.closeButton.snp.centerY)
        }
        
        // bottom view layout
        bottomView.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf)
            make.right.equalTo(strongSelf)
            make.bottom.equalTo(strongSelf)
            make.height.equalTo(52)
        }
        
        playButtion.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.left.equalTo(strongSelf.bottomView).offset(20)
            make.height.equalTo(25)
            make.width.equalTo(25)
            make.centerY.equalTo(strongSelf.bottomView)
        }
        
        timeLabel.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.right.equalTo(strongSelf.fullscreenButton.snp.left).offset(-10)
            make.centerY.equalTo(strongSelf.playButtion)
            make.height.equalTo(30)
        }
        
        timeSlider.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.centerY.equalTo(strongSelf.playButtion)
            make.right.equalTo(strongSelf.timeLabel.snp.left).offset(-10)
            make.left.equalTo(strongSelf.playButtion.snp.right).offset(25)
            make.height.equalTo(25)
        }
        fullscreenButton.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.centerY.equalTo(strongSelf.playButtion)
            make.right.equalTo(strongSelf.bottomView).offset(-10)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
        
        loadingIndicator.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.center.equalTo(strongSelf)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
    }
}
