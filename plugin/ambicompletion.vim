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
"   g:AmbiCompletion_richerSupportForMultibyte = 1
"       (obsolete in the future, recher only)
"
"       gives up completion using Python (even though you have +python),
"       and enables richer extraction of multibyte characters.
"
"           0: x10 quicker and poorer multibyte support. NOT TESTED WELL
"           1: Richer multibyte support.
"
"   g:AmbiCompletion_allBuffers = 0
"       (obsolete in the future)
"
"       decides from where to collect word samples.
"
"           0: Collects from only in the current buffer.
"           1: Collects from all over the buffers.
"
"       Note this value is ignored when recher support for multibyte is enabled.
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
"   AmbiCompletionEnableCaching
"   AmbiCompletionDisableCaching
"      will be disappeared
"

if !exists('g:AmbiCompletion_richerSupportForMultibyte') 
    let g:AmbiCompletion_richerSupportForMultibyte = 1
endif

if !exists('g:AmbiCompletion_allBuffers') 
    let g:AmbiCompletion_allBuffers = 0
endif

if !exists('g:AmbiCompletion_cacheCheckpoint') 
    let g:AmbiCompletion_cacheCheckpoint = 10
endif

let g:AmbiCompletion__wordSplitter = '\(.\zs\ze\@>\(\<\|\>\)\)'
let g:AmbiCompletion__wordSplitter = '\>\zs\ze\<\|\<\|\>'
let g:AmbiCompletion__wordSplitter = '\>\zs\ze\<\|\<\|\>\|\s'

let g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD = 0.7


command! AmbiCompletionRefreshCache call <SID>forceUpdateWordsCache()



function! g:AmbiCompletionPython(findstart, base, all_buffers)
    let l:base = iconv(a:base, &encoding, 'utf-8')
    let all_buffers = a:all_buffers
silent python <<EOF
import re
import string
import sys
import vim

WORD_SPLITTER_REGEXP_WORD = re.compile(ur'\W+', re.UNICODE)
WORD_SPLITTER_REGEXP_NONWORD = re.compile(ur'\w+', re.UNICODE)

INTERCHANGE_ENCODING = 'utf-8'


def lcs(word1, word2, word1re=None):
    word1 = word1.lower()
    word2 = word2.lower()
    len1 = len(word1) + 1
    len2 = len(word2) + 1

    if word1re and not word1re.search(word2):
        return 0

    #print('word1: ' + word1)
    #print('word2: ' + word2)
    #print('len1: '+ str(len1))
    #print('len2: '+ str(len2))
    #print('range(1, len1-1): ' + str(range(1, len1)))
    #print('range(1, len2-1): ' + str(range(1, len2)))

    prev = [0] * len2
    curr = [0] * len2

    for i1 in range(1, len1):
        for i2 in range(1, len2):
            #print('word1['+str(i1 - 1)+']: ' + word1[i1 - 1])
            #print('word2['+str(i2 - 1)+']: ' + word2[i2 - 1])
            if word1[i1 - 1] == word2[i2 - 1]:
                x = 1
                if 0 <= i1 - 2 and 0 <= i2 - 2 and word1[i1 - 2] == word2[i2 - 2]:
                    #
                    x = 2
            else:
                x = 0
            curr[i2] = max(prev[i2 - 1] + x, prev[i2], curr[i2 - 1])
            #print 'curr[i2]: ' + str(curr[i2])
        temp = prev
        prev = curr
        curr = temp
        #print prev
    #print prev
    return prev[len2 - 1]


def cmp_word_and_lcs(word1, word2):
    if word1[1] > word2[1]:
        return -1
    elif word1[1] < word2[1]:
        return 1
    elif len(word1[0]) < len(word2[0]):
        return -1
    elif len(word1[0]) > len(word2[0]):
        return 1
    elif word1[0] < word2[0]:
        return -1
    elif word1[0] > word2[0]:
        return 1
    else:
        return 0


LCSV_COEFFICIENT_THRESHOLD = 0.7


def complete(base, all_buffers):
    base = base.decode(INTERCHANGE_ENCODING)
    #basere = re.compile(u'[' + base + ']'
    #            \ , re.IGNORECASE | re.LOCALE | re.UNICODE)
    basere = None
    selflcsv = lcs(base, base, None)

    results = []
    wordset = set()
    baselen = len(base)

    if int(all_buffers):
        for buff in vim.buffers:
            for line in [temp_line.decode(vim.eval('&encoding'), 'ignore')
                        \ for temp_line in buff]:
                for word in WORD_SPLITTER_REGEXP_WORD.split(line):
                    wordset.add(word)
                for word in WORD_SPLITTER_REGEXP_NONWORD.split(line):
                    wordset.add(word)
    else:
        for line in [temp_line.decode(vim.eval('&encoding'), 'ignore')
                    \ for temp_line in vim.current.buffer]:
            for word in WORD_SPLITTER_REGEXP_WORD.split(line):
                wordset.add(word)
            for word in WORD_SPLITTER_REGEXP_NONWORD.split(line):
                wordset.add(word)
    for word in wordset:
        lcsv = lcs(base, word, basere)
        if selflcsv * LCSV_COEFFICIENT_THRESHOLD <= lcsv:
            results.append([word, lcsv])
    results.sort(cmp=cmp_word_and_lcs)
    return results

base = vim.eval('l:base')
all_buffers = vim.eval('l:all_buffers')
result = complete(base, all_buffers)
complret = u'['
complret += u', '.join(
                    u"{'word':'%s', 'menu':%s}" % (
                        r[0].replace("\\", "\\\\").replace("'", "''"),
                        unicode(r[1])
                    )
                    for r in result
                )
complret += u']'
vim.command(''.join([
                'let g:complret=eval(\'',
                complret.encode(vim.eval('&encoding'), 'ignore').replace("'", "''"),
                '\')'
            ]))
EOF
    return g:complret
endfunction



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

    if has('python') && g:AmbiCompletion_richerSupportForMultibyte == 0
        let results = g:AmbiCompletionPython(a:findstart, a:base, g:AmbiCompletion_allBuffers)
        ""call s:HOGE('4_ ')
        return results
    endif

"call s:HOGE('4.1 updating cache')
    call s:updateWordsCache()
"call s:HOGE('4.1 updated cache')

    let CUTBACK_REGEXP = '\V\[' . join(sort(split(a:base, '\zs')), '') . ']'

    "let min_word_len = (baselen SLASH threshold + 1) SLASH 2
    " ^ causes strange syn highlighting...
    let min_word_len = baselen / g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD / 2 + 1 / 2

    let results = []
    let wordset = {}
    if exists('s:AmbiCompletion_cache')
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

            "let lcs = s:AmbiCompletion__LCS(a:base, word)
            let lcs = s:AmbiCompletion__LCS(split(a:base, '\zs'), split(word, '\zs'))
            if 0 < lcs && baselen <= lcs * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD
                call add(results, [word, lcs])
            endif
        endfor
"call s:HOGE('5 cache end ' . string(len(results)))
    else
"call s:HOGE('5 NO cache')
        for line in getline(1, '$')
            for word in split(line, g:AmbiCompletion__wordSplitter)
                if word == ''
                    continue
                endif

                let word_elem_len = len(split(word, '\zs'))
                "echom word . ' ' . string(word_elem_len)
                if word_elem_len < min_word_len
                    continue
                endif

                if has_key(wordset, word)
                    continue
                endif

                if word !~ CUTBACK_REGEXP
                    continue
                endif

                "let lcs = s:AmbiCompletion__LCS(a:base, word)
                let lcs = s:AmbiCompletion__LCS(split(a:base, '\zs'), split(word, '\zs'))
                if 0 < lcs && baselen <= lcs * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD
                    call add(results, [word, lcs])
                endif

                let wordset[word] = 1
            endfor
        endfor
    endif
    "call s:HOGE('6 word gathering')

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
    let curr = deepcopy(prev) "repeat([0], len2)

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
    return float2nr(round(prev[len2-1] * strlen(substitute(a:word1, '.', 'x', 'g')) * 1.0 / strlen(a:word1)))
    return prev[len2-1]
endfunction

"augroup AmbiCompletion
"    autocmd!
"
"    autocmd  CursorHold   *  call <SID>updateWordsCache()
"    autocmd  CursorHoldI  *  call <SID>updateWordsCache()
"augroup END

command! AmbiCompletionEnableCaching call <SID>enableCaching()
function! s:enableCaching()
    call s:disableCaching()

    call s:updateWordsCache()

    augroup AmbiCompletion
        autocmd!
        autocmd  CursorHold   *  call <SID>updateWordsCache()
        "autocmd  CursorHoldI  *  call <SID>updateWordsCache()
    augroup END
endfunction

command! AmbiCompletionDisableCaching call <SID>disableCaching()
function! s:disableCaching()
    if exists('s:AmbiCompletion_cache')
        unlet s:AmbiCompletion_cache
    endif
    if exists('s:AmbiCompletion_bufnr')
        unlet s:AmbiCompletion_bufnr
    endif

    augroup AmbiCompletion
        autocmd!
    augroup END
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
    "echom 'buff:' . last_bufnr . '->' . curr_bufnr . ', seq:' . last_seq . '->' . curr_seq

    let s:AmbiCompletion_bufnr = curr_bufnr
    let b:AmbiCompletion_seq = curr_seq + 1 "completion only operation progresses seq

    " gather words
    let cachewords = []
    for line in getline(1, '$')
        for word in split(line, g:AmbiCompletion__wordSplitter)
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
    let w1len = strlen(a:w1)
    let w2len = strlen(a:w2)
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
