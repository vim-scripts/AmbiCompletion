" AmbiCompletion -- Ambiguous completion.
"
" Maintainer: Shuhei Kubota <kubota.shuhei+vim@gmail.com>
" Description:
"   This script provides an ambiguous completion functionality.
"   For those who are forgetful.
"
"   This is a fork of Word Fuzzy Completion.
"   (http://www.vim.org/scripts/script.php?script_id=3857)
"
"   THIS IS BETA QUALITY.
"
" Usage:
"   Set completefunc to g:AmbiCompletion.
"
"   like :set completefunc=g:AmbiCompletion
"
" Variables:
"
"   (A right hand side value is a default value.)
"
"   g:AmbiCompletion_cacheCheckpoint = 10
"
"       cache-updating interval.
"       The cache is updated when undo sequence progresses by this value.
" 
" Commands:
"   
"   AmbiCompletionRefreshCache
"
"       updates the cache immediately.
"

if !exists('g:AmbiCompletion_cacheCheckpoint') 
    let g:AmbiCompletion_cacheCheckpoint = 10
endif

let g:AmbiCompletion__WORD_SPLITTER = '\>\zs\ze\<\|\<\|\>\|\s'
let g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD = 0.7

command! AmbiCompletionRefreshCache call <SID>forceUpdateWordsCache()

function! g:AmbiCompletion(findstart, base)
"call s:HOGE('1 ' . undotree().seq_cur)
    if a:findstart
"call s:HOGE('2')
        " Get cursor word.
        let cur_text = strpart(getline('.'), 0, col('.') - 1)
"call s:HOGE('3')
        "return match(cur_text, '\V\w\+\$')

        " I want get a last word(maybe a multi-byte char)!!
        let cur_words = split(cur_text, '\<')
        if len(cur_words) == 0
            return match(cur_text, '\V\w\+\$')
        else
            let last_word = cur_words[-1]
            "echom 'last_word:' . last_word
            "echom 'result:' . strridx(cur_text, last_word)
            return strridx(cur_text, last_word)
        endif
    endif
    let baselen = strlen(substitute(a:base, '.', 'x', 'g'))
    "let baselen = strlen(a:base)
"call s:HOGE('4')
	if baselen == 0
		return []
	endif

"call s:HOGE('4.1 updating cache')
    call s:updateWordsCache()
"call s:HOGE('4.1 updated cache')

    let CUTBACK_REGEXP = '\V\[' . join(sort(split(a:base, '\zs')), '') . ']'

    let min_word_len = (baselen / g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD + 1) 
                \ / 2

    let results = []
    let wordset = {}
"call s:HOGE('5 cache (min:' . string(min_word_len) . ')')

    for word in s:AmbiCompletion_cache
        if word == ''
            continue
        endif

        let word_elem_len = len(split(word, '\zs'))
        "echom word . ' ' . string(word_elem_len)
        if word_elem_len < min_word_len
            "echom word
            break
        endif

        if word !~ CUTBACK_REGEXP
            continue
        endif

        " simulate ideal max lcs value
        let len_match_elems = word_elem_len - len(split(substitute(word, CUTBACK_REGEXP, '', 'g'), '\zs'))
        let sim_ideal_lcsv = len_match_elems * 2 - 1
        if baselen >= sim_ideal_lcsv * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD
            "echom 'SKIPPED ' . word . ' ideal=' . string(sim_ideal_lcsv) . ', baselen=' . string(baselen)
            continue
        endif

        "let lcs = s:AmbiCompletion__LCS(a:base, word)
        let lcs = s:AmbiCompletion__LCS(split(a:base, '\zs'), split(word, '\zs'))
        if 0 < lcs && baselen <= lcs * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD
            call add(results, [word, lcs])
        endif
    endfor
"call s:HOGE('6 word gathering ' . string(len(results)))

    "LCS
    call sort(results, function('s:AmbiCompletion__compare'))
"call s:HOGE('7')
    return map(results, '{''word'': v:val[0], ''menu'': v:val[1]}')
endfunction

function! s:AmbiCompletion__compare(word1, word2)
    if a:word1[1] > a:word2[1]
        return -1
    elseif a:word1[1] < a:word2[1]
        return 1
    elseif len(a:word1[0]) < len(a:word2[0])
        return -1
    elseif len(a:word1[0]) > len(a:word2[0])
        return 1
    elseif a:word1[0] < a:word2[0]
        return -1
    elseif a:word1[0] > a:word2[0]
        return 1
    else
        return 0
    endif
endfunction

function! s:AmbiCompletion__LCS(word1, word2)
    let w1 = a:word1
    let w2 = a:word2
    let len1 = len(w1) + 1
    let len2 = len(w2) + 1

    let prev = repeat([0], len2)
    let curr = repeat([0], len2)

    "echom string(prev)
    for i1 in range(1, len1 - 1)
        for i2 in range(1, len2 - 1)
            "echom 'w1['.(i1-1).']:'.w1[i1-1]
            "echom 'w2['.(i2-1).']:'.w2[i2-1]
            if w1[i1-1] == w2[i2-1]
                let x = 1
                if 0 <= i1-2 && 0 <= i2-2 && w1[i1-2] == w2[i2-2]
                    let x = 2
                endif
            else
                let x = 0
            endif
            let curr[i2] = max([ prev[i2-1] + x, prev[i2], curr[i2-1] ])
        endfor
        let temp = prev
        let prev = curr
        let curr = temp
        "echom string(prev)
    endfor
    "echom string(prev)
    return prev[len2-1] "mutibyte cared
endfunction

function! s:forceUpdateWordsCache()
    let s:AmbiCompletion_bufnr = -1
    call s:updateWordsCache()
endfunction

function! s:updateWordsCache()
    " bufvars
    let last_bufnr = 0
    if exists('s:AmbiCompletion_bufnr')
        let last_bufnr = s:AmbiCompletion_bufnr
    endif
    let last_seq = 0
    if exists('b:AmbiCompletion_seq')
        let last_seq = b:AmbiCompletion_seq
    endif

    let curr_bufnr = bufnr('%')
    let curr_seq = s:getLastUndoSeq()

    " latest, nop
    if curr_bufnr == last_bufnr && curr_seq < last_seq + g:AmbiCompletion_cacheCheckpoint
        return
    endif
    echom 'buff:' . last_bufnr . '->' . curr_bufnr . ', seq:' . last_seq . '->' . curr_seq

    let s:AmbiCompletion_bufnr = curr_bufnr
    let b:AmbiCompletion_seq = curr_seq + 1 "completion only operation progresses seq

    " gather words
    let cachewords = []
    for line in getline(1, '$')
        for word in split(line, g:AmbiCompletion__WORD_SPLITTER)
            if word != ''
                call add(cachewords, word)
            endif
        endfor
    endfor
    " uniq by alphabet
    if exists('*uniq')
        call sort(cachewords)
        call uniq(cachewords)
    else
        let cwdict = {}
        for word in cachewords
            let cwdict[word] = 1
        endfor
        let cachewords = sort(keys(cwdict))
    endif
    " sort by length for future optimization
    call sort(cachewords, function('s:strlencompare'))

    "echom string(cachewords)

    " store in cache
    let s:AmbiCompletion_cache = cachewords
    return
endfunction

function! s:getLastUndoSeq()
    let ut = undotree()
    if has_key(ut, 'seq_last')
        return ut.seq_last
    endif

    return 0
endfunction

function! s:getCurrUndoSeq()
    let ut = undotree()
    if has_key(ut, 'seq_cur')
        return ut.seq_cur
    endif

    return 0
endfunction

function! s:strlencompare(w1, w2)
    let w1len = len(split(a:w1, '\zs'))
    let w2len = len(split(a:w2, '\zs'))
    if w1len < w2len
        return 1
    elseif w1len == w2len
        return 0
    else
        return -1
    endif
endfunction

function! s:TEST(word1, word2) "
    echom 'LCS(' . a:word1 . ', ' . a:word2 . ') => ' . string(s:AmbiCompletion__LCS(a:word1, a:word2))
endfunction

"call s:TEST('aaa', 'aa')

let s:HOGE_RELSTART = reltime()
function! s:HOGE(msg)
    echom strftime('%c') . ' ' . reltimestr(reltime(s:HOGE_RELSTART)) .  ' ' . a:msg
    let s:HOGE_RELSTART = reltime()
endfunction
" call s:HOGE('')
