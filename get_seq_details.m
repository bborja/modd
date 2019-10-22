function [vid_seq_name, start_frame, end_frame] = get_seq_details(vid_num)
    switch vid_num
        case 1
            vid_seq_name = 'kope67-00-00004500-00005050';
        case 2
            vid_seq_name = 'kope67-00-00025200-00025670';
        case 3
            vid_seq_name = 'kope67-00-00027400-00027650';
        case 4
            vid_seq_name = 'kope67-00-00040950-00041190';
        case 5
            vid_seq_name = 'kope67-00-00060561-00061461';
        case 6
            vid_seq_name = 'kope67-00-00061851-00062671';
        case 7
            vid_seq_name = 'kope67-00-00062671-00063461';
        case 8
            vid_seq_name = 'kope67-00-00067272-00067942';
        case 9
            vid_seq_name = 'kope67-00-00074432-00074612';
        case 10
            vid_seq_name = 'kope71-01-00011210-00011320';
        case 11
            vid_seq_name = 'kope71-01-00011520-00011800';
        case 12
            vid_seq_name = 'kope71-01-00011800-00012000';
        case 13
            vid_seq_name = 'kope71-01-00014337-00014547';
        case 14
            vid_seq_name = 'kope71-01-00017650-00017825';
        case 15
            vid_seq_name = 'kope75-00-00013780-00014195';
        case 16
            vid_seq_name = 'kope75-00-00021500-00022160';
        case 17
            vid_seq_name = 'kope75-00-00037550-00037860';
        case 18
            vid_seq_name = 'kope75-00-00062200-00062500';
        case 19
            vid_seq_name = 'kope81-00-00000560-00001080';
        case 20
            vid_seq_name = 'kope81-00-00004330-00004850';
        case 21
            vid_seq_name = 'kope81-00-00006800-00007095';
        case 22
            vid_seq_name = 'kope81-00-00010940-00011100';
        case 23
            vid_seq_name = 'kope81-00-00015980-00016270';
        case 24
            vid_seq_name = 'kope81-00-00019370-00019710';
        case 25
            vid_seq_name = 'kope81-00-00021520-00022080';
        case 26
            vid_seq_name = 'kope81-00-00022350-00022520';
        case 27
            vid_seq_name = 'kope82-00-00011177-00011797';
        case 28
            vid_seq_name = 'kope82-00-00012030-00012700';
    end
    
    tmp_split = strsplit(vid_seq_name, '-');
    start_frame = str2double(tmp_split(3));
    end_frame = str2double(tmp_split(4));
end