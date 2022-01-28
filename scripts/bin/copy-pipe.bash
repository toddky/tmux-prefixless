#!/usr/bin/env bash
if (type ,copy &>/dev/null); then
	,copy
elif (type xclip &>/dev/null); then
	xclip -selection clipboard
	xclip -selection primary
fi

