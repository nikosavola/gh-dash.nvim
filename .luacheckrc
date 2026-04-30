-- .luacheckrc
std = 'luajit'
globals = { 'vim', 'describe', 'it', 'before_each', 'after_each', 'pending', 'assert', 'eq' }
ignore = {
  '212', -- unused argument (common in callbacks)
}

max_line_length = false
