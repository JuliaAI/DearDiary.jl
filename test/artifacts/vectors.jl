sha256_empty_input() = DearDiary.sha256_hex(UInt8[])
sha256_abc_input() = DearDiary.sha256_hex(UInt8[0x61, 0x62, 0x63])

# 56 bytes — long enough to force a second block of padding.
function sha256_long_input()
    return DearDiary.sha256_hex(
        Vector{UInt8}("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    )
end
