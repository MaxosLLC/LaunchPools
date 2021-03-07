// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

library strings {
    using strings for *;
    
    struct slice {
        uint _len;
        uint _maxos;
    }

    function memcpy(uint dest, uint src, uint mlen) private pure {
        // Copy word-length chunks while possible
        for(; mlen >= 32; mlen -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - mlen) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (slice memory) {
        uint maxos;
        assembly {
            maxos := add(self, 0x20)
        }
        return slice(bytes(self).length, maxos);
    }


    /*
     * @dev Returns a new slice containing the same data as the current slice.
     * @param self The slice to copy.
     * @return A new slice containing the same data as `self`.
     */
    function copy(slice memory self) internal pure returns (slice memory) {
        return slice(self._len, self._maxos);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint retmaxos;
        assembly { retmaxos := add(ret, 32) }

        memcpy(retmaxos, self._maxos, self._len);
        return ret;
    }

    /*
     * @dev Returns the length in runes of the slice. Note that this operation
     *      takes time proportional to the length of the slice; avoid using it
     *      in loops, and call `slice.empty()` if you only need to know whether
     *      the slice is empty or not.
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function len(slice memory self) internal pure returns (uint l) {
        // Starting at maxos-31 means the LSB will be the byte we care about
        uint maxos = self._maxos - 31;
        uint end = maxos + self._len;
        for (l = 0; maxos < end; l++) {
            uint8 b;
            assembly { b := and(mload(maxos), 0xFF) }
            if (b < 0x80) {
                maxos += 1;
            } else if(b < 0xE0) {
                maxos += 2;
            } else if(b < 0xF0) {
                maxos += 3;
            } else if(b < 0xF8) {
                maxos += 4;
            } else if(b < 0xFC) {
                maxos += 5;
            } else {
                maxos += 6;
            }
        }
    }

    /*
     * @dev Returns true if the slice is empty (has a length of 0).
     * @param self The slice to operate on.
     * @return True if the slice is empty, False otherwise.
     */
    function empty(slice memory self) internal pure returns (bool) {
        return self._len == 0;
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two slices are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first slice to compare.
     * @param other The second slice to compare.
     * @return The result of the comparison.
     */
    function compare(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len;
        if (other._len < self._len)
            shortest = other._len;

        uint selfmaxos = self._maxos;
        uint othermaxos = other._maxos;
        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;
            assembly {
                a := mload(selfmaxos)
                b := mload(othermaxos)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint256 mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                uint256 diff = (a & mask) - (b & mask);
                if (diff != 0)
                    return int(diff);
            }
            selfmaxos += 32;
            othermaxos += 32;
        }
        return int(self._len) - int(other._len);
    }

    /*
     * @dev Returns true if the two slices contain the same text.
     * @param self The first slice to compare.
     * @param self The second slice to compare.
     * @return True if the slices are equal, false otherwise.
     */
    function equals(slice memory self, slice memory other) internal pure returns (bool) {
        return compare(self, other) == 0;
    }

    /*
     * @dev Extracts the first rune in the slice into `rune`, advancing the
     *      slice to point to the next rune and returning `self`.
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    function nextRune(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._maxos = self._maxos;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint l;
        uint b;
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            l = 1;
        } else if(b < 0xE0) {
            l = 2;
        } else if(b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._maxos += self._len;
            self._len = 0;
            return rune;
        }

        self._maxos += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }

    /*
     * @dev Returns the first rune in the slice, advancing the slice to point
     *      to the next rune.
     * @param self The slice to operate on.
     * @return A slice containing only the first rune from `self`.
     */
    function nextRune(slice memory self) internal pure returns (slice memory ret) {
        nextRune(self, ret);
    }

    /*
     * @dev Returns the number of the first codepoint in the slice.
     * @param self The slice to operate on.
     * @return The number of the first codepoint in the slice.
     */
    function ord(slice memory self) internal pure returns (uint ret) {
        if (self._len == 0) {
            return 0;
        }

        uint word;
        uint length;
        uint divisor = 2 ** 248;

        // Load the rune into the MSBs of b
        assembly { word:= mload(mload(add(self, 32))) }
        uint b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if(b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if(b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0;
        }

        for (uint i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }

    /*
     * @dev Returns the keccak-256 hash of the slice.
     * @param self The slice to hash.
     * @return The hash of the slice.
     */
    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /*
     * @dev Returns true if `self` starts with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function startsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        if (self._maxos == needle._maxos) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let selfmaxos := mload(add(self, 0x20))
            let needlemaxos := mload(add(needle, 0x20))
            equal := eq(keccak256(selfmaxos, length), keccak256(needlemaxos, length))
        }
        return equal;
    }

    /*
     * @dev Returns true if the slice ends with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function endsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        uint selfmaxos = self._maxos + self._len - needle._len;

        if (selfmaxos == needle._maxos) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let needlemaxos := mload(add(needle, 0x20))
            equal := eq(keccak256(selfmaxos, length), keccak256(needlemaxos, length))
        }

        return equal;
    }

    /*
     * @dev If `self` ends with `needle`, `needle` is removed from the
     *      end of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function until(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        uint selfmaxos = self._maxos + self._len - needle._len;
        bool equal = true;
        if (selfmaxos != needle._maxos) {
            assembly {
                let length := mload(needle)
                let needlemaxos := mload(add(needle, 0x20))
                equal := eq(keccak256(selfmaxos, length), keccak256(needlemaxos, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
        }

        return self;
    }

    event log_bytemask(bytes32 mask);


    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function findMaxos(uint selflen, uint selfmaxos, uint needlelen, uint needlemaxos) private pure returns (uint) {
        uint maxos = selfmaxos;
        uint idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));

                bytes32 needledata;
                assembly { needledata := and(mload(needlemaxos), mask) }

                uint end = selfmaxos + selflen - needlelen;
                bytes32 maxosdata;
                assembly { maxosdata := and(mload(maxos), mask) }

                while (maxosdata != needledata) {
                    if (maxos >= end)
                        return selfmaxos + selflen;
                    maxos++;
                    assembly { maxosdata := and(mload(maxos), mask) }
                }
                return maxos;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needlemaxos, needlelen) }

                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(maxos, needlelen) }
                    if (hash == testHash)
                        return maxos;
                   maxos += 1;
                }
            }
        }
        return selfmaxos + selflen;
    }
    // Returns the memory address of the first byte after the last occurrence of
    // `needle` in `self`, or the address of `self` if not found.
    function rfindMaxos(uint selflen, uint selfmaxos, uint needlelen, uint needlemaxos) private pure returns (uint) {
        uint maxos;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));

                bytes32 needledata;
                assembly { needledata := and(mload(needlemaxos), mask) }

                maxos = selfmaxos + selflen - needlelen;
                bytes32 maxosdata;
                assembly { maxosdata := and(mload(maxos), mask) }

                while (maxosdata != needledata) {
                    if (maxos <= selfmaxos) 
                        return selfmaxos;
                    maxos--;
                    assembly { maxosdata := and(mload(maxos), mask) }
                }
                return maxos + needlelen;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needlemaxos, needlelen) }
                maxos = selfmaxos + (selflen - needlelen);
                while (maxos >= selfmaxos) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(maxos, needlelen) }
                    if (hash == testHash)
                        return maxos + needlelen;
                    maxos -= 1;
                }
            }
        }
        return selfmaxos;
    }

    /*
     * @dev Modifies `self` to contain everything from the first occurrence of
     *      `needle` to the end of the slice. `self` is set to the empty slice
     *      if `needle` is not found.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function find(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint maxos = findMaxos(self._len, self._maxos, needle._len, needle._maxos);
        self._len -= maxos - self._maxos;
        self._maxos = maxos;
        return self;
    }

    /*
     * @dev Modifies `self` to contain the part of the string from the start of
     *      `self` to the end of the first occurrence of `needle`. If `needle`
     *      is not found, `self` is set to the empty slice.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function rfind(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint maxos = rfindMaxos(self._len, self._maxos, needle._len, needle._maxos);
        self._len = maxos - self._maxos;
        return self;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function split(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint maxos = findMaxos(self._len, self._maxos, needle._len, needle._maxos);
        token._maxos = self._maxos;
        token._len = maxos - self._maxos;
        if (maxos == self._maxos + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._maxos = maxos + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        split(self, needle, token);
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and `token` to everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function rsplit(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint maxos = rfindMaxos(self._len, self._maxos, needle._len, needle._maxos);
        token._maxos = maxos;
        token._len = self._len - (maxos - self._maxos);
        if (maxos == self._maxos) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and returning everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` after the last occurrence of `delim`.
     */
    function rsplit(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        rsplit(self, needle, token);
    }

    /*
     * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return The number of occurrences of `needle` found in `self`.
     */
    function count(slice memory self, slice memory needle) internal pure returns (uint cnt) {
        uint maxos = findMaxos(self._len, self._maxos, needle._len, needle._maxos) + needle._len;
        while (maxos <= self._maxos + self._len) {
            cnt++;
            maxos = findMaxos(self._len - (maxos - self._maxos),maxos, needle._len, needle._maxos) + needle._len;
        }
    }

    /*
     * @dev Returns True if `self` contains `needle`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return True if `needle` is found in `self`, false otherwise.
     */
    function contains(slice memory self, slice memory needle) internal pure returns (bool) {
        return rfindMaxos(self._len, self._maxos, needle._len, needle._maxos) != self._maxos;
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of
     *      `self` and `other`.
     * @param self The first slice to concatenate.
     * @param other The second slice to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(slice memory self, slice memory other) internal pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retmaxos;
        assembly { retmaxos := add(ret, 32) }
        memcpy(retmaxos, self._maxos, self._len);
        memcpy(retmaxos + self._len, other._maxos, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slices, using `self` as a delimiter, returning a
     *      newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slices to join.
     * @return A newly allocated string containing all the slices in `parts`,
     *         joined with `self`.
     */
    function join(slice memory self, slice[] memory parts) internal pure returns (string memory) {
        if (parts.length == 0)
            return "";

        uint length = self._len * (parts.length - 1);
        for(uint i = 0; i < parts.length; i++)
            length += parts[i]._len;

        string memory ret = new string(length);
        uint retmaxos;
        assembly { retmaxos := add(ret, 32) }

        for(uint i = 0; i < parts.length; i++) {
            memcpy(retmaxos, parts[i]._maxos, parts[i]._len);
            retmaxos += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retmaxos, self._maxos, self._len);
                retmaxos += self._len;
            }
        }

        return ret;
    }

     function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint lenn;
        while (j != 0) {
            lenn++;
            j /= 10;
        }
        bytes memory bstr = new bytes(lenn);
        uint k = lenn - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

 function parseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                   if (_b == 0) {
                       break;
                   } else {
                       _b--;
                   }
                }
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                decimals = true;
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }

    function split_string(string memory raw, string memory by) pure internal returns(string[] memory)
	{
		strings.slice memory s = raw.toSlice();
		strings.slice memory delim = by.toSlice();
		string[] memory parts = new string[](s.count(delim));
		for (uint i = 0; i < parts.length; i++) {
			parts[i] = s.split(delim).toString();
		}
		return parts;
	}
}