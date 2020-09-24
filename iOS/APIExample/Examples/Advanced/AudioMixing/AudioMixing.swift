//
//  AudioMixingMain.swift
//  APIExample
//
//  Created by ADMIN on 2020/5/18.
//  Copyright © 2020 Agora Corp. All rights reserved.
//

import UIKit
import AgoraRtcKit
import AGEVideoLayout

class AudioMixingEntry : UIViewController
{
    @IBOutlet weak var joinButton: AGButton!
    @IBOutlet weak var channelTextField: AGTextField!
    @IBOutlet weak var scenarioBtn: UIButton!
    @IBOutlet weak var profileBtn: UIButton!
    var profile:AgoraAudioProfile = .default
    var scenario:AgoraAudioScenario = .default
    let identifier = "AudioMixing"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        profileBtn.setTitle("\(profile.description())", for: .normal)
        scenarioBtn.setTitle("\(scenario.description())", for: .normal)
    }
    
    @IBAction func doJoinPressed(sender: AGButton) {
        guard let channelName = channelTextField.text else {return}
        //resign channel text field
        channelTextField.resignFirstResponder()
        
        let storyBoard: UIStoryboard = UIStoryboard(name: identifier, bundle: nil)
        // create new view controller every time to ensure we get a clean vc
        guard let newViewController = storyBoard.instantiateViewController(withIdentifier: identifier) as? BaseViewController else {return}
        newViewController.title = channelName
        newViewController.configs = ["channelName":channelName, "audioProfile":profile, "audioScenario":scenario]
        self.navigationController?.pushViewController(newViewController, animated: true)
    }
    
    func getAudioProfileAction(_ profile:AgoraAudioProfile) -> UIAlertAction{
        return UIAlertAction(title: "\(profile.description())", style: .default, handler: {[unowned self] action in
            self.profile = profile
            self.profileBtn.setTitle("\(profile.description())", for: .normal)
        })
    }
    
    func getAudioScenarioAction(_ scenario:AgoraAudioScenario) -> UIAlertAction{
        return UIAlertAction(title: "\(scenario.description())", style: .default, handler: {[unowned self] action in
            self.scenario = scenario
            self.scenarioBtn.setTitle("\(scenario.description())", for: .normal)
        })
    }
    
    @IBAction func setAudioProfile(){
        let alert = UIAlertController(title: "Set Audio Profile", message: nil, preferredStyle: .actionSheet)
        for profile in AgoraAudioProfile.allValues(){
            alert.addAction(getAudioProfileAction(profile))
        }
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func setAudioScenario(){
        let alert = UIAlertController(title: "Set Audio Scenario", message: nil, preferredStyle: .actionSheet)
        for scenario in AgoraAudioScenario.allValues(){
            alert.addAction(getAudioScenarioAction(scenario))
        }
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
}

class AudioMixingMain: BaseViewController {
    var agoraKit: AgoraRtcEngineKit!
    @IBOutlet var container: AGEVideoContainer!
    @IBOutlet var audioMixingVolumeSlider: UISlider!
    @IBOutlet var audioMixingPlaybackVolumeSlider: UISlider!
    @IBOutlet var audioMixingPublishVolumeSlider: UISlider!
    var audioViews: [UInt:VideoView] = [:]
    
    // indicate if current instance has joined channel
    var isJoined: Bool = false
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        // set up agora instance when view loaded
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: KeyCenter.AppId, delegate: self)
        
        guard let channelName = configs["channelName"] as? String,
            let audioProfile = configs["audioProfile"] as? AgoraAudioProfile,
            let audioScenario = configs["audioScenario"] as? AgoraAudioScenario
            else {return}
        
        audioMixingPlaybackVolumeSlider.setValue(Float(agoraKit.getAudioMixingPlayoutVolume()), animated: true)
        audioMixingPublishVolumeSlider.setValue(Float(agoraKit.getAudioMixingPublishVolume()), animated: true)
        
        // disable video module
        agoraKit.disableVideo()
        
        // set audio profile/audio scenario
        agoraKit.setAudioProfile(audioProfile, scenario: audioScenario)
        
        // Set audio route to speaker
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        // enable volume indicator
        agoraKit.enableAudioVolumeIndication(200, smooth: 3, report_vad: false)
        
        
        // start joining channel
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. If app certificate is turned on at dashboard, token is needed
        // when joining channel. The channel name and uid used to calculate
        // the token has to match the ones used for channel join
        let result = agoraKit.joinChannel(byToken: nil, channelId: channelName, info: nil, uid: 0) {[unowned self] (channel, uid, elapsed) -> Void in
            self.isJoined = true
            LogUtils.log(message: "Join \(channel) with uid \(uid) elapsed \(elapsed)ms", level: .info)
            
            //set up local audio view, this view will not show video but just a placeholder
            let view = Bundle.loadVideoView(type: .local, audioOnly: true)
            self.audioViews[0] = view
            view.setPlaceholder(text: self.getAudioLabel(uid: uid, isLocal: true))
            self.container.layoutStream2x1(views: self.sortedViews())
        }
        if result != 0 {
            // Usually happens with invalid parameters
            // Error code description can be found at:
            // en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            // cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            // leave channel when exiting the view
            if isJoined {
                agoraKit.leaveChannel { (stats) -> Void in
                    LogUtils.log(message: "left channel, duration: \(stats.duration)", level: .info)
                }
            }
        }
    }
    
    func sortedViews() -> [VideoView] {
        return Array(audioViews.values).sorted(by: { $0.uid < $1.uid })
    }
    
    @IBAction func onChangeAudioMixingVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("adjustAudioMixingVolume \(value)")
        agoraKit.adjustAudioMixingVolume(value)
    }
    
    @IBAction func onChangeAudioMixingPlaybackVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("adjustAudioMixingPlayoutVolume \(value)")
        agoraKit.adjustAudioMixingPlayoutVolume(value)
    }
    
    @IBAction func onChangeAudioMixingPublishVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("adjustAudioMixingPublishVolume \(value)")
        agoraKit.adjustAudioMixingPublishVolume(value)
    }
}

/// agora rtc engine delegate events
extension AudioMixingMain: AgoraRtcEngineDelegate {
    /// callback when warning occured for agora sdk, warning can usually be ignored, still it's nice to check out
    /// what is happening
    /// Warning code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// @param warningCode warning code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        LogUtils.log(message: "warning: \(warningCode.description)", level: .warning)
    }
    
    /// callback when error occured for agora sdk, you are recommended to display the error descriptions on demand
    /// to let user know something wrong is happening
    /// Error code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// @param errorCode error code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        LogUtils.log(message: "error: \(errorCode)", level: .error)
        self.showAlert(title: "Error", message: "Error \(errorCode.description) occur")
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        LogUtils.log(message: "remote user join: \(uid) \(elapsed)ms", level: .info)

        //set up remote audio view, this view will not show video but just a placeholder
        let view = Bundle.loadVideoView(type: .remote, audioOnly: true)
        view.uid = uid
        self.audioViews[uid] = view
        view.setPlaceholder(text: self.getAudioLabel(uid: uid, isLocal: false))
        self.container.layoutStream2x1(views: sortedViews())
        self.container.reload(level: 0, animated: true)
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        LogUtils.log(message: "remote user left: \(uid) reason \(reason)", level: .info)
        
        //remove remote audio view
        self.audioViews.removeValue(forKey: uid)
        self.container.layoutStream2x1(views: sortedViews())
        self.container.reload(level: 0, animated: true)
    }
    
    /// Reports which users are speaking, the speakers' volumes, and whether the local user is speaking.
    /// @params speakers volume info for all speakers
    /// @params totalVolume Total volume after audio mixing. The value range is [0,255].
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for volumeInfo in speakers {
            if let audioView = audioViews[volumeInfo.uid] {
                audioView.setInfo(text: "Volume:\(volumeInfo.volume)")
            }
        }
    }
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        audioViews[0]?.statsInfo?.updateChannelStats(stats)
    }
    
    /// Reports the statistics of the uploading local audio streams once every two seconds.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStats stats: AgoraRtcLocalAudioStats) {
        audioViews[0]?.statsInfo?.updateLocalAudioStats(stats)
    }
    
    /// Reports the statistics of the audio stream from each remote user/host.
    /// @param stats stats struct for current call statistics
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStats stats: AgoraRtcRemoteAudioStats) {
        audioViews[stats.uid]?.statsInfo?.updateAudioStats(stats)
    }
}
