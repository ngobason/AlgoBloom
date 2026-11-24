-- AlgoBloom Development Seed Data (Migration 002)
-- NOTE: Demo password hashes below are placeholders. Replace with real bcrypt/argon2 hashes in W13 auth setup.

-- 1. Seed Demo Teacher & Student
INSERT INTO users (id, email, password_hash, full_name, role)
VALUES
    ('11111111-1111-4111-8111-111111111111', 'teacher.lan@algobloom.edu.vn', '$2a$10$REPLACE_WITH_REAL_BCRYPT_HASH_TEACHER', 'Tran Thi Lan', 'TEACHER'),
    ('11111111-1111-4111-8111-111111111112', 'student.minh@algobloom.edu.vn', '$2a$10$REPLACE_WITH_REAL_BCRYPT_HASH_STUDENT', 'Nguyen Van Minh', 'STUDENT')
ON CONFLICT (email) DO NOTHING;

-- 2. Seed Codeforces-Style Algorithmic Tags
INSERT INTO tags (id, slug, name, category)
VALUES
    ('22222222-2222-4222-8222-222222222201', 'dp', 'Dynamic Programming', 'ALGORITHM'),
    ('22222222-2222-4222-8222-222222222202', 'binary-search', 'Binary Search', 'TECHNIQUE'),
    ('22222222-2222-4222-8222-222222222203', 'graphs', 'Graphs', 'ALGORITHM'),
    ('22222222-2222-4222-8222-222222222204', 'segment-tree', 'Segment Tree', 'DATA_STRUCTURE'),
    ('22222222-2222-4222-8222-222222222205', 'greedy', 'Greedy', 'ALGORITHM'),
    ('22222222-2222-4222-8222-222222222206', 'two-pointers', 'Two Pointers', 'TECHNIQUE'),
    ('22222222-2222-4222-8222-222222222207', 'trees', 'Trees', 'DATA_STRUCTURE'),
    ('22222222-2222-4222-8222-222222222208', 'number-theory', 'Number Theory', 'ALGORITHM')
ON CONFLICT (slug) DO NOTHING;

-- 3. Seed Focal Verified Problem (`dp` + `binary-search`, difficulty 1600)
INSERT INTO problems (
    id, slug, title, statement_md, input_format_md, output_format_md, constraints_md,
    difficulty, time_limit_ms, memory_limit_mb, target_complexity,
    sample_cases, subtask_tiers, generator_code, reference_solution_cpp, storage_path,
    status, created_by
)
VALUES (
    '33333333-3333-4333-8333-333333333301',
    'longest-increasing-energy-chain',
    'Longest Increasing Energy Chain',
    'Given an array of N reactor nodes where node i has energy level a_i, select the longest strictly increasing subsequence of reactor nodes so the chain stabilizes without overload.',
    'First line contains an integer N (1 <= N <= 10^5). Second line contains N integers a_1, a_2, ..., a_N (1 <= a_i <= 10^9).',
    'Print a single integer — the maximum chain length.',
    'Subtask 1 (25 pts): N <= 100. Subtask 2 (25 pts): N <= 1,000. Subtask 3 (25 pts): N <= 10,000. Subtask 4 (25 pts): N <= 100,000.',
    1600,
    2000,
    256,
    'O(N log N)',
    '[{"input":"6\n10 9 2 5 3 7","output":"3","explanation":"One longest strictly increasing subsequence is [2, 3, 7]."}]'::jsonb,
    '[{"tier":1,"max_n":100,"points":25,"time_limit_ms":2000},{"tier":2,"max_n":1000,"points":25,"time_limit_ms":2000},{"tier":3,"max_n":10000,"points":25,"time_limit_ms":2000},{"tier":4,"max_n":100000,"points":25,"time_limit_ms":2000}]'::jsonb,
    E'import random, sys\nn = int(sys.argv[1])\nseed = int(sys.argv[2])\nrng = random.Random(seed)\nprint(n)\nprint(" ".join(str(rng.randint(1, 10**9)) for _ in range(n)))\n',
    E'#include <bits/stdc++.h>\nusing namespace std;\nint main(){ios::sync_with_stdio(false);cin.tie(nullptr);int n;cin>>n;vector<int> t;for(int i=0;i<n;i++){int x;cin>>x;auto it=lower_bound(t.begin(),t.end(),x);if(it==t.end())t.push_back(x);else *it=x;}cout<<t.size()<<"\\n";}\n',
    '/data/problems/33333333-3333-4333-8333-333333333301',
    'PUBLISHED',
    '11111111-1111-4111-8111-111111111111'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO problem_tags (problem_id, tag_id)
VALUES
    ('33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201'),
    ('33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222202')
ON CONFLICT DO NOTHING;
