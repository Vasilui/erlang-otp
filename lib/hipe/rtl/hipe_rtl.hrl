
-record(rtl, {'fun', args, code, data, var_range, label_range, info=[]}).

-record(move, {dst, src, info}).
-record(multimove, {dst, src, info}).
-record(alu, {dst, src1, op, src2, info}).
-record(load, {dst, src, off, info}).
-record(store, {dst, off, src, info}).
-record(load_address, {dst, address, type, info}).
-record(branch, {src1, src2, cond, true_label, false_label, p, info}).
-record(switch, {src, labels, sorted_by=[], info}).
-record(alub, {dst, src1, op, src2, cond, true_label, false_label, p, info}).
-record(jsr, {'fun', type, args, continuation, failcontinuation, info}).
-record(esr, {'fun', type, args, info}).
-record(call, {dst, 'fun', args, type, continuation, failcontinuation, info}).
-record(enter, {'fun', args, type, info}).
-record(return, {vars, info}).
-record(jmp, {target, off, args, info}).
-record(jmp_link, {target, off, link, args, continuation, failcontinuation, info}).
-record(stackneed, {words, info}).
-record(gctest, {words, info}).
-record(load_tagged, {dst, src, off, tag, info}).
-record(load_atom, {dst, atom, info}).
-record(load_word_index, {dst, block, index, info}).
-record(goto_index, {block, index, labels, info}).
-record(label, {name, info}).
-record(save_frame, {vars, info}).
-record(restore_frame, {vars, info}).
-record(restore_catch, {vars, info}).
-record(pop_frame, {vars, info}).
-record(comment, {text, info}).
-record(goto, {label, info}).
-record(fail_to, {reason, label, info}).