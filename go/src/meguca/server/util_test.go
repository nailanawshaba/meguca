package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"meguca/config"
	"meguca/db"
)

func newRequest(url string) *http.Request {
	return httptest.NewRequest("GET", url, nil)
}

func newPair(url string) (*httptest.ResponseRecorder, *http.Request) {
	return httptest.NewRecorder(), newRequest(url)
}

func assertCode(t *testing.T, rec *httptest.ResponseRecorder, std int) {
	t.Helper()
	if rec.Code != std {
		t.Errorf("unexpected status code: %d : %d", std, rec.Code)
	}
}

func assertTableClear(t *testing.T, tables ...string) {
	t.Helper()
	if err := db.ClearTables(tables...); err != nil {
		t.Fatal(err)
	}
}

func assertEtag(t *testing.T, rec *httptest.ResponseRecorder, etag string) {
	t.Helper()
	if s := rec.Header().Get("ETag"); s != etag {
		t.Errorf("unexpected etag: %s : %s", etag, s)
	}
}

func assertBody(t *testing.T, rec *httptest.ResponseRecorder, body string) {
	t.Helper()
	if s := rec.Body.String(); s != body {
		const f = "unexpected response body:\nexpected: `%s`\ngot:      `%s`"
		t.Errorf(f, body, s)
	}
}

func assertHeaders(
	t *testing.T,
	rec *httptest.ResponseRecorder,
	h map[string]string,
) {
	t.Helper()
	for key, val := range h {
		if s := rec.Header().Get(key); s != val {
			t.Errorf("unexpected header %s value: %s : %s", key, val, s)
		}
	}
}

func marshalJSON(t *testing.T, msg interface{}) []byte {
	t.Helper()

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func setBoards(t *testing.T, boards ...string) {
	t.Helper()

	config.ClearBoards()
	for _, b := range boards {
		_, err := config.SetBoardConfigs(config.BoardConfigs{
			ID: b,
		})
		if err != nil {
			t.Fatal(err)
		}
	}
}

func TestText404(t *testing.T) {
	t.Parallel()

	rec, req := newPair("/lalala/")
	router.ServeHTTP(rec, req)
	assertCode(t, rec, 404)
	assertBody(t, rec, "404 not found\n")
}

func TestText40X(t *testing.T) {
	t.Parallel()

	cases := [...]struct {
		code int
		fn   func(http.ResponseWriter, error)
	}{
		{400, text400},
		{403, text403},
	}

	for i := range cases {
		c := cases[i]
		t.Run(strconv.Itoa(c.code), func(t *testing.T) {
			t.Parallel()

			rec := httptest.NewRecorder()
			c.fn(rec, errors.New("foo"))
			assertCode(t, rec, c.code)
			assertBody(t, rec, fmt.Sprintf("%d foo\n", c.code))
		})
	}
}
