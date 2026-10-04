-- Run from the addon root with Lua 5.1: lua tools/test_predict.lua
local passed, failed = 0, 0
local function check(name, test)
    local ok, err = pcall(test)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function fixture(language)
    local CK = {
        db = { settings = { maxWords = 3, dicts = {} }, words = {}, starts = {}, bigrams = {}, trigrams = {} },
        Dicts = {}, Normalize = string.lower, Lower = string.lower,
        IsUpperInitial = function() return false end,
        GetLanguage = function() return { key = language, accents = language == "fren" and "fr" or language } end,
    }
    wipe = function(t) for key in pairs(t) do t[key] = nil end end
    assert(loadfile("Predict.lua"))("EasyController", CK)
    return CK.Predict, CK.db, CK
end

check("equal-frequency overflow removes only the excess deterministically", function()
    local p, db = fixture("en")
    db.words = { alpha = 1, bravo = 1, charlie = 1, delta = 1 }
    p:Prune()
    assert(p:NumLearned() == 3, "expected 3 retained words, got " .. p:NumLearned())
    assert(not db.words.alpha and db.words.bravo and db.words.charlie and db.words.delta)
end)

check("high-frequency overflow still respects capacity", function()
    local p, db = fixture("en")
    db.words = { alpha = 1000, bravo = 1100, charlie = 1200, delta = 1300 }
    p:Prune()
    assert(p:NumLearned() == 3, "counts above 999 must still be pruned")
    assert(not db.words.alpha and db.words.delta == 1300)
end)

check("words at capacity stay intact", function()
    local p, db = fixture("en")
    db.words = { alpha = 1, bravo = 2, charlie = 3 }
    p:Prune()
    assert(p:NumLearned() == 3 and db.words.alpha == 1 and db.words.charlie == 3)
end)

check("pruning retains valid context and removes references to discarded words", function()
    local p, db = fixture("en")
    db.settings.maxWords = 2
    db.words = { discarded = 1, retained = 3, another = 4 }
    db.starts = { discarded = 1, retained = 2, a = 1, ["j'"] = 1 }
    db.bigrams = { retained = { discarded = 1, another = 2, a = 1 }, discarded = { retained = 1 },
        ["j'"] = { retained = 1 } }
    db.trigrams = { ["retained another"] = { discarded = 1, retained = 2 },
        ["discarded retained"] = { another = 1 }, ["a j'"] = { retained = 1 } }
    p:Prune()
    assert(not db.starts.discarded and db.starts.retained == 2 and db.starts.a and db.starts["j'"])
    assert(not db.bigrams.discarded and not db.bigrams.retained.discarded)
    assert(db.bigrams.retained.another == 2 and db.bigrams.retained.a and db.bigrams["j'"].retained)
    assert(not db.trigrams["discarded retained"] and not db.trigrams["retained another"].discarded)
    assert(db.trigrams["retained another"].retained == 2 and db.trigrams["a j'"].retained)
end)

check("the default 8000-word capacity loses one word, not the vocabulary", function()
    local p, db = fixture("en")
    db.settings.maxWords = 8000
    for i = 1, 8001 do db.words["word" .. i] = 1 end
    p:Prune()
    assert(p:NumLearned() == 8000, "expected exactly 8000 words after pruning")
end)

local expected = {
    fr = "et,de,pour,le,la", fren = "et,de,pour,le,la", en = "and,the,to,for,a",
    de = "und,die,der,zu,für", es = "y,de,para,el,la", it = "e,di,per,il,la",
}
for _, language in ipairs({ "fr", "fren", "en", "de", "es", "it" }) do
    check("next-word fallback follows " .. language, function()
        local p = fixture(language)
        p:Load()
        assert(table.concat(p:Query("", { prev = "unseen" }, 5), ",") == expected[language])
        assert(#p:Query("", { start = true }, 5) == 0, "fallback must not replace message-start behavior")
    end)
end

check("learned context outranks fallback and prefix completion remains unchanged", function()
    local p, db = fixture("en")
    db.words = { invited = 2, inventory = 1 }
    db.bigrams.please = { invited = 1 }
    p:Load()
    assert(p:Query("", { prev = "please" }, 5)[1] == "invited")
    local out = p:Query("inv", { start = true }, 5)
    assert(#out == 2 and out[1] == "invited" and out[2] == "inventory")
end)

assert(failed == 0, failed .. " prediction regression tests failed")
print(passed .. " prediction regression tests passed")
