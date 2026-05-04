import AVFoundation

extension AVQueuePlayer {
    /// `AVPlayerLooper` phát **bản sao** trong queue, không phải template. Gắn lại output lên `currentItem` mỗi khi queue đổi.
    func lj_rehomeVideoOutput(_ output: AVPlayerItemVideoOutput) {
        for it in items() {
            if it.outputs.contains(where: { $0 === output }) {
                it.remove(output)
            }
        }
        currentItem?.add(output)
    }
}

enum PlayerLooperVideoOutputBinding {
    /// Gắn output lên item đang phát và lặp lại khi `currentItem` thay đổi (Looper đổi replica).
    static func observeCurrentItem(
        player: AVQueuePlayer,
        output: AVPlayerItemVideoOutput
    ) -> NSKeyValueObservation {
        player.lj_rehomeVideoOutput(output)
        return player.observe(\.currentItem, options: [.initial, .new]) { pl, _ in
            DispatchQueue.main.async {
                pl.lj_rehomeVideoOutput(output)
            }
        }
    }
}
