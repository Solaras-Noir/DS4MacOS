/// Player indicator LED masks (5 bits, centre based). Source: kernel L1722-1728 and pydualsense PlayerID.
public enum PlayerLEDs {
    /// All LEDs off.
    public static let none: UInt8 = 0x00
    /// Player 1, `--x--`.
    public static let player1: UInt8 = 0x04
    /// Player 2, `-x-x-`.
    public static let player2: UInt8 = 0x0A
    /// Player 3, `x-x-x`.
    public static let player3: UInt8 = 0x15
    /// Player 4, `xx-xx`.
    public static let player4: UInt8 = 0x1B
    /// All five LEDs.
    public static let all: UInt8 = 0x1F

    /// The mask for player 1 to 4; 0 gives none, 5 gives all. Other values return nil.
    public static func mask(player: Int) -> UInt8? {
        switch player {
        case 0: return none
        case 1: return player1
        case 2: return player2
        case 3: return player3
        case 4: return player4
        case 5: return all
        default: return nil
        }
    }
}
