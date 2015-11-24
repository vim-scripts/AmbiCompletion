" AmbiCompletion -- Ambiguous completion.
"
" Maintainer: Shuhei Kubota <kubota.shuhei+vim@gmail.com>
" Description:
"
"   This script provides an ambiguous completion functionality.
"
"   A long function name, tired to type, a vague memory of spelling, ...
"   Ambiguous completion supports you with similar words in your buffer.
"
"   Your type does not need to match the beginning of answer word.
"   "egining" -> "beginning"
"   
"   For those who are forgetful.
"
"   This is a fork of the first version of Word Fuzzy Completion.
"   (http://www.vim.org/scripts/script.php?script_id=3857)
"   adding middle-word-match, architectural changes(mainly no need +python), global candidates.
"
" Usage:
"
"   1. Set completefunc to g:AmbiCompletion.
"
"       :set completefunc=g:AmbiCompletion
"
"       "optional
"       :inoremap <C-U>  <C-X><C-U>
"
"   2. (optional) If you have globally useful dictionary, then
"
"       :AmbiCompletionAddGlobal  my/favorite/dictfile
"       :AmbiCompletionAddGlobal  my/favorite/another
"       "this makes completion actions slow down
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
"   g:AmbiCompletion_cacheShorteningFactors = {'0': 0.1, '100': 0.25, '500': 0.5, '1000': 0.75, '5000': 1}
"
"       cach-updating factors. {'line-order': cache-updating factor, ...}
"       In small size file, caches are updated frequently. In large size file,
"       caches are updated less frequently.
" 
" Commands:
"   
"   AmbiCompletionRefreshCache
"
"       updates the cache in a current buffer immediately.
"   
"   AmbiCompletionAddGlobal {filename}...
"
"       adds words in {filename} into word candidates.
"       Multiple {filename} are allowed.
"
" Memo:
"
"   g:AmbiCompletion__DEBUG = 0
"   
"       outputs (does :echom) each completion logs.
"
"   b:AmbiCompletion_seq
"
"      last seq number of a buffer.
"      Used for updating caches of a current buffer.  (curr_seq < last_seq + cp*factor)
"

if !exists('g:AmbiCompletion_cacheShorteningFactors')
    let g:AmbiCompletion_cacheShorteningFactors = {'0': 0.1, '100': 0.25, '500': 0.5, '1000': 0.75, '5000': 1}
endif

if !exists('g:AmbiCompletion_cacheCheckpoint')
    let g:AmbiCompletion_cacheCheckpoint = 10
endif

let g:AmbiCompletion__WORD_SPLITTER = '\>\zs\ze\<\|\<\|\>\|\s'
let g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD = 0.57 " neet->neat ok
let g:AmbiCompletion__DEBUG = 0

command! AmbiCompletionRefreshCache call <SID>forceUpdateWordsCache()
command! -nargs=+ -complete=file  AmbiCompletionAddGlobal call <SID>addGlobal(<f-args>)

let s:recurring = 0

function! g:AmbiCompletion(findstart, base)

    " Find a target word

    if a:findstart
        " Get cursor word.
        let cur_text = strpart(getline('.'), 0, col('.') - 1)
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

    " Complete
call s:HOGE('=== start completion ===')

    " Care about a multi-byte word
    let baselen = strlen(substitute(a:base, '.', 'x', 'g'))
    let base_self_lcsv = s:AmbiCompletion__LCS(split(a:base, '\zs'), split(a:base, '\zs'))
    "let baselen = strlen(a:base)

	if baselen == 0
		return []
	endif

call s:HOGE('vvv updating cache vvv')
    " Updating may be skipped internally
"echom string(b:AmbiCompletion_cache)
    let updated = s:updateWordsCache()
"echom '=> updated ='.string(updated)
"echom string(b:AmbiCompletion_cache)
call s:HOGE('^^^ updated cache ^^^')

    " Candidates need contain at least one char in a:base
    let CONTAINDEDIN_REGEXP = '\V\[' . join(sort(split(a:base, '\zs')), '') . ']'
    " Candidates need have their length at least considered-similar LSV value
    let min_word_elem_len = (base_self_lcsv * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD + 1) / 2

    let results = []
    let wordset = {}

call s:HOGE('vvv merging global candidates vvv')
    " shallow-copied OR DEEP-COPIED
    let candidates = b:AmbiCompletion_cache

    " if there are global candidates, merge them into l:candidates
    if len(s:AmbiCompletion__global) > 0
        let candidates = copy(b:AmbiCompletion_cache)
        call extend(candidates, s:AmbiCompletion__global)

        " uniq by alphabet
        if exists('*uniq')
            call sort(candidates)
            call uniq(candidates)
        else
            let cwdict = {}
            for word in candidates
                let cwdict[word] = 1
            endfor
            let candidates = sort(keys(cwdict))
        endif

        " sort by length for future optimization
        call sort(candidates, function('s:strlencompare'))

        echom 'candidates:' . string(len(candidates)) . ', buffer:' . string(len(b:AmbiCompletion_cache)) . ', global:' . string(len(s:AmbiCompletion__global))
    endif
call s:HOGE('^^^ merged global candidates ^^^')

call s:HOGE('vvv pre-filtering candidates('. string(len(b:AmbiCompletion_cache)) . ') vvv')
    "let candidates = copy(b:AmbiCompletion_cache)
    "call filter(candidates, 'v:val =~ ''' . CONTAINDEDIN_REGEXP . '''')
    "call filter(candidates, 'len(split(v:val, ''\zs'')) >= ' . string(min_word_elem_len))
    "call filter(candidates, string(base_self_lcsv * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD) . ' <= (len(split(v:val, ''\zs'')) - len(split(substitute(v:val, ''' . CONTAINDEDIN_REGEXP . ''', '''', ''g''), ''\zs''))) * 2 - 1')
call s:HOGE('^^^ pre-filtered candidates('. string(len(candidates)) . ') ^^^')

call s:HOGE('vvv filtering candidates vvv')
    for word in candidates
        let word_elem_len = len(split(word, '\zs'))
        if word_elem_len < min_word_elem_len
            break
        endif

        if word !~ CONTAINDEDIN_REGEXP
            continue
        endif

        " a count of matched (a:base and word) elements
        let matched_elems_len = word_elem_len - len(split(substitute(word, CONTAINDEDIN_REGEXP, '', 'g'), '\zs'))
        " simulate ideal max lcs value
        let matched_ideal_lcsv = matched_elems_len * 2 - 1
        if base_self_lcsv * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD > matched_ideal_lcsv
            continue
        endif

        "let lcsv = s:AmbiCompletion__LCS(a:base, word)
        let lcsv = s:AmbiCompletion__LCS(split(a:base, '\zs'), split(word, '\zs'))
        if 0 < lcsv && base_self_lcsv * g:AmbiCompletion__LCSV_COEFFICIENT_THRESHOLD <= lcsv
            call add(results, [word, lcsv])
        else
        endif
    endfor
call s:HOGE('^^^ filtered candidates'.len(results).' ^^^')

    "LCS
    call sort(results, function('s:AmbiCompletion__compare'))
call s:HOGE('sorted results')

    if len(results) == 0 && !updated && !s:recurring
        " detect irritating situation
        call s:forceUpdateWordsCache()
        let s:recurring = 1
        let result = g:AmbiCompletion(a:findstart, a:base)
        let s:recurring = 0
        return result
    endif

call s:HOGE('=== end completion ===')
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
    if exists('b:AmbiCompletion_cache')
        unlet b:AmbiCompletion_cache
    endif
    call s:updateWordsCache()
endfunction

" returns updated or not
function! s:updateWordsCache()
    " bufvars
    let last_seq = 0
    if exists('b:AmbiCompletion_seq')
        let last_seq = b:AmbiCompletion_seq
    endif

    let curr_seq = s:getLastUndoSeq()

    " latest, nop
    let cp = g:AmbiCompletion_cacheCheckpoint
    let line_count = line('$')
    for k in keys(g:AmbiCompletion_cacheShorteningFactors)
        let line_order = str2nr(k)
        if line_order <= line_count
            let cp = g:AmbiCompletion_cacheCheckpoint * g:AmbiCompletion_cacheShorteningFactors[k]
        endif
    endfor

    if exists('b:AmbiCompletion_cache') && curr_seq < last_seq + cp
        return 0
    endif
"echom 'seq:' . last_seq . '->' . curr_seq . ', cp:' . string(cp)

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

    " store cache
    let b:AmbiCompletion_cache = cachewords
    return 1
endfunction

let s:AmbiCompletion__global = []
let s:AmbiCompletion__globalFilenames = []
function! s:addGlobal(...)
    let s:AmbiCompletion__global = []
    call extend(s:AmbiCompletion__globalFilenames, a:000)

    " gather words
    let cachewords = []
    for f in s:AmbiCompletion__globalFilenames
        for line in readfile(f)
            for word in split(line, g:AmbiCompletion__WORD_SPLITTER)
                if word != ''
                    call add(cachewords, word)
                endif
            endfor
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

    " store
    let s:AmbiCompletion__global = cachewords
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

"call s:TEST('ne', 'ne')

let s:HOGE_RELSTART = reltime()
function! s:HOGE(msg)
    if g:AmbiCompletion__DEBUG
        echom strftime('%c') . ' ' . reltimestr(reltime(s:HOGE_RELSTART)) .  ' ' . a:msg
        let s:HOGE_RELSTART = reltime()
    endif
endfunction
